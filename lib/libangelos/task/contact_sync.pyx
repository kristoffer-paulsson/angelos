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
"""A task for synchronizing and indexing contacts in relation to portfolios."""
import asyncio

from libangelos.task.task import TaskFacadeExtension


class ContactPortfolioSyncTask(TaskFacadeExtension):
    """Task extension that runs as a background job in the facade."""

    ATTRIBUTE = ("contact_sync",)

    INVOKABLE = (True,)

    async def _run(self) -> None:
        contacts = self.facade.api.contact
        portfolios = await self.facade.storage.vault.list_portfolios() - {self.facade.data.portfolio.entity.id}
        every = await contacts.load_all()
        blocked = await contacts.load_blocked()
        await asyncio.sleep(0)
        self._progress(.25)

        # Remove the intersection of "blocked" and "all" from all.
        remove_all_from_blocked = blocked | every
        await asyncio.gather(*[contacts.block(p) for p in remove_all_from_blocked])
        await asyncio.sleep(0)
        self._progress(.50)

        # Remove the union of "all" and "blocked" intersected from "portfolios" and remove them.
        remove_all = (every | blocked) - portfolios
        await asyncio.gather(*[contacts.remove(p)  for p in remove_all])
        await asyncio.sleep(0)
        self._progress(.75)

        # Subtract "blocked" from "portfolios", then add missing to "all".
        add_all = (portfolios - blocked) - every
        await asyncio.gather(*[self.__link(contacts.PATH_ALL[0], p) for p in add_all])
        await asyncio.sleep(0)

        # await contacts.remove(self.facade.data.portfolio.entity.id)
        self._progress(1.0)
        
    async def __link(self, path, eid):
        filename = path + str(eid)
        target = self.facade.storage.vault.PATH_PORTFOLIOS[0] + str(eid) + "/" + str(eid) + ".ent"
        await self.facade.storage.vault.link(filename, target)
