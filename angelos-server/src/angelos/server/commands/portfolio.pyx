# cython: language_level=3
#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#
import pprint
import uuid

from angelos.server.cmd import Command, Option
from angelos.lib.error import PortfolioAlreadyExists
from angelos.lib.operation.export import ExportImportOperation
from angelos.lib.policy.format import PrintPolicy
from angelos.lib.policy.portfolio import PGroup
from angelos.lib.policy.verify import StatementPolicy


class PortfolioCommand(Command):
    """Work with portfolios."""

    abbr = """View/Import/Export portfolios and documentes."""
    description = """Use this command to work with documents and portfolios."""

    def __init__(self, io, facade):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, "port", io)
        self.__facade = facade

    async def _command(self, opts):
        if opts["import"]:
            await self.__import()
        elif opts["export"]:
            await self.__export(opts["export"], opts["group"])
        elif opts["view"]:
            await self.__view(opts["view"], opts["group"])
        elif opts["list"]:
            await self.__list()
            # await self.__list(opts["list"])
        else:
            pass

    async def __import(self):
        """"""
        data = await self._io.multiline("Import portfolio")
        portfolio = ExportImportOperation.text_imp(data)

        if not portfolio:
            self._io << "\nInvalid data entered\n\n"
            return

        issuer, owner = portfolio.to_sets()
        for doc in issuer | owner:
            self._io << doc.__class__.__name__ + "\n"
            pprint.pprint(doc.export_yaml(), self._io.stdout)
            self._io << "\n\n"

        imp = await self._io.confirm(
            "Confirm that you want to import this portfolio"
        )
        if imp:
            try:
                statements = portfolio.issuer.to_set() | portfolio.owner.to_set()
                await self.__facade.storage.vault.import_portfolio(portfolio)
                await self.__facade.storage.vault.statements_portfolio(statements)
            except PortfolioAlreadyExists as e:
                statements = portfolio.issuer.to_set() | portfolio.owner.to_set()
                await self.__facade.storage.vault.update_portfolio(portfolio)
                await self.__facade.storage.vault.statements_portfolio(statements)

    async def __export(self, entity_id, group):
        if entity_id == "self":
            entity_id = self.__facade.data.portfolio.entity.id
        else:
            entity_id = uuid.UUID(entity_id)

        portfolio = await self.__facade.storage.vault.load_portfolio(
            entity_id, self.__group(group)
        )
        portfolio.privkeys = None
        self._io << ExportImportOperation.text_exp(portfolio)
        self._io << "\n\n"

    async def __view(self, entity_id, group):
        entity_id = uuid.UUID(entity_id)
        portfolio = await self.__facade.storage.vault.load_portfolio(
            entity_id, self.__group(group)
        )

        if not portfolio:
            self._io << "\nInvalid data entered\n\n"
            return

        portfolio.privkeys = None

        issuer, owner = portfolio.to_sets()
        for doc in issuer | owner:
            self._io << doc.__class__.__name__ + "\n"
            pprint.pprint(doc.export_yaml(), self._io.stdout)
            self._io << "\n\n"

        if portfolio.entity.id == self.__facade.data.portfolio.entity.id:
            return

        verified = StatementPolicy.validate_verified(
            self.__facade.data.portfolio, portfolio
        )
        trusted = StatementPolicy.validate_trusted(
            self.__facade.data.portfolio, portfolio
        )

        v_renewable = False
        t_renewable = False

        if verified:
            if verified.expires_soon():
                v_renewable = True
        if trusted:
            if trusted.expires_soon():
                t_renewable = True

        s1 = "Create verified statement"
        s2 = "Renew verified statement"
        s3 = "Revoke verified statement"
        s4 = "Create trusted statement"
        s5 = "Renew trusted statement"
        s6 = "Revoke trusted statement"

        do = await self._io.menu(
            "Portfolio statement management",
            [
                self._io.dim(s1) if verified else s1,
                s2 if v_renewable else self._io.dim(s2),
                s3 if verified else self._io.dim(s3),
                self._io.dim(s4) if trusted else s4,
                s5 if t_renewable else self._io.dim(s5),
                s6 if trusted else self._io.dim(s6),
                "Continue",
            ],
        )

        statement = None
        if do == 0 and not verified:
            statement = StatementPolicy.verified(
                self.__facade.data.portfolio, portfolio
            )
        elif do == 1 and v_renewable:
            statement = StatementPolicy.verified(
                self.__facade.data.portfolio, portfolio
            )
        elif do == 2 and verified:
            statement = StatementPolicy.revoked(
                self.__facade.data.portfolio, verified
            )
        elif do == 3 and not trusted:
            statement = StatementPolicy.trusted(
                self.__facade.data.portfolio, portfolio
            )
        elif do == 4 and t_renewable:
            statement = StatementPolicy.trusted(
                self.__facade.data.portfolio, portfolio
            )
        elif do == 5 and trusted:
            statement = StatementPolicy.revoked(
                self.__facade.data.portfolio, trusted
            )

        if statement:
            await self.__facade.storage.vault.statements_portfolio(set([statement]))
            self._io << "\nSaved statement changes to portfolio.\n"

    async def __list(self):
        self._io << "\n"
        for eid in await self.__facade.storage.vault.list_portfolios():
            portfolio = await self.__facade.storage.vault.load_portfolio(eid, PGroup.VERIFIER)
            print(portfolio)
            self._io << (
                PrintPolicy.title(portfolio)
                + "; "
                + str(portfolio.entity.id)
                + "\n"
            )
        self._io << "\n"

    def __group(self, group):
        if group == "verify":
            return PGroup.VERIFIER
        elif group == "min":
            return PGroup.SHARE_MIN_COMMUNITY
        elif group == "med":
            return PGroup.SHARE_MED_COMMUNITY
        elif group == "max":
            return PGroup.SHARE_MAX_COMMUNITY
        elif group == "all":
            return PGroup.ALL
        else:
            return PGroup.SHARE_MED_COMMUNITY

    def _rules(self):
        return {
            "exclusive": [
                "import",
                "export",
                "view",
                "list",
                "revoke",
                "verify",
                "trust",
            ],
            "option": [
                "import",
                "export",
                "view",
                "list",
                "revoke",
                "verify",
                "trust",
            ],
            "group": [("export", "view"), None, None, None],
        }

    def _options(self):
        """
        Return a list of Option class configurations.

        Overide this method.
        """
        return [
            Option(
                "import",
                abbr="i",
                type=Option.TYPE_BOOL,
                help="Import documents to portfolio",
            ),
            Option(
                "export",
                abbr="e",
                type=Option.TYPE_VALUE,
                help="Export portfolio",
            ),
            Option(
                "view", abbr="v", type=Option.TYPE_VALUE, help="View portfolio"
            ),
            Option(
                "list",
                abbr="l",
                type=Option.TYPE_VALUE,
                help="List portfolio entries",
                default="*",
            ),
            Option(
                "group",
                abbr="g",
                type=Option.TYPE_CHOICES,
                choices=["verify", "min", "med", "max", "all"],
                default="med",
                help="Load portfolio group",
            ),
            Option(
                "revoke",
                abbr="r",
                type=Option.TYPE_VALUE,
                help="List portfolio statement",
            ),
            Option(
                "verify",
                abbr="f",
                type=Option.TYPE_VALUE,
                help="Verify portfolio entity",
            ),
            Option(
                "trust",
                abbr="t",
                type=Option.TYPE_VALUE,
                help="Trust portfolio entity",
            ),
        ]

    @classmethod
    def factory(cls, **kwargs):
        """Create command with facade from IoC."""
        return cls(kwargs["io"], kwargs["ioc"].facade)