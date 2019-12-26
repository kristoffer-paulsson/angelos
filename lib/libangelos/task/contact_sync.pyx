# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""A task for synchronizing and indexing contacts in relation to portfolios."""
import asyncio

from libangelos.task.task import TaskFacadeExtension


class ContactPortfolioSyncTask(TaskFacadeExtension):
    """Task extension that runs as a background job in the facade."""

    ATTRIBUTE = ("contact_sync",)

    INVOKABLE = (True,)

    async def _run(self) -> None:
        contacts = self.facade.api.contact
        portfolios = await self.facade.storage.vault.list_portfolios()
        all = await contacts.load_all()
        blocked = await contacts.load_blocked()
        await asyncio.sleep(0)
        self._progress(.25)

        # Remove the intersection of "blocked" and "all" from all.
        remove_all_from_blocked = blocked | all
        await  asyncio.gather(*[contacts.block(p) for p in remove_all_from_blocked])
        await asyncio.sleep(0)
        self._progress(.50)

        # Remove the union of "all" and "blocked" intersected from "portfolios" and remove them.
        remove_all = (all | blocked) - portfolios
        await asyncio.gather(*[contacts.remove(p)  for p in remove_all])
        await asyncio.sleep(0)
        self._progress(.75)

        # Subtract "blocked" from "portfolios", then add missing to "all".
        add_all = (portfolios - blocked) - all
        await asyncio.gather(*[self.__link(contacts.PATH_ALL[0], p) for p in portfolios])
        await asyncio.sleep(0)
        self._progress(1.0)
        
    async def __link(self, path, eid):
        await self.facade.storage.vault.link(
            path + str(eid),
            self.facade.storage.vault.PATH_PORTFOLIOS[0] + str(eid) + "/" + str(eid) + ".ent"
        )
