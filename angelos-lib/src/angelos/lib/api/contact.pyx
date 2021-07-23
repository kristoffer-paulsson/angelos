# cython: language_level=3, linetrace=True
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
"""Facade contact API."""
import uuid
from typing import Tuple, Set

from angelos.angelos.api.api import ApiFacadeExtension
from angelos.lib.facade.base import BaseFacade


class ContactAPI(ApiFacadeExtension):
    """ContactAPI is an interface class, placed on the facade."""

    ATTRIBUTE = ("contact",)

    PATH_BLOCKED = ("/contacts/blocked/",)
    PATH_ALL = ("/contacts/all/",)
    PATH_FRIENDS = ("/contacts/friends/",)
    PATH_FAVORITES = ("/contacts/favorites/",)

    def __init__(self, facade: BaseFacade):
        """Initialize the Contacts."""
        ApiFacadeExtension.__init__(self, facade)

    async def __load_contacts(self, pattern: str) -> Set[Tuple[uuid.UUID]]:
        """Loads all contacts according to pattern.

        Args:
            pattern (str):
                Search pattern for specific contact folder

        Returns (Set[Tuple[str, uuid.UUID]]):
            Result file path and owner ID.

        """
        result = await self.facade.storage.vault.search(
            pattern,
            link=True,
            limit=0,
            deleted=False,
            fields=lambda name, entry: (name, entry.owner)
        )
        return set(result.keys())

    async def __link(self, path: str, eid: uuid.UUID):
        """Link a contact to a portfolio entity.

        Args:
            path (str):
                Path to contact directory.
            eid (uuid.UUID):
                Portfolio entity ID

        """
        await self.facade.storage.vault.link(
            path + str(eid),
            self.facade.storage.vault.PATH_PORTFOLIOS[0] + str(eid) + "/" + str(eid) + ".ent"
        )

    async def __unlink(self, path: str, eid: uuid.UUID):
        """Remove contact by unlink portfolio entity.

        Args:
            path (str):
                Path in contact directory.
            eid (uuid.UUID):
                Portfolio entity ID

        """
        await self.facade.storage.vault.delete(path + str(eid))

    async def load_all(self) -> Set[Tuple[str, uuid.UUID]]:
        """Load a list of all contacts, that is not blocked.

        Returns (List[Tuple[str, uuid.UUID]]):
            List of tuples with portfolio path and ID.

        """
        return await self.__load_contacts(self.PATH_ALL[0] + "*")

    async def status(self, eid: uuid.UUID) -> Tuple[bool, bool, bool]:
        """Check the status of a contact against the categories if they are favorites and/or friends.

        Args:
            eid (uuid.UUID):
                The contact to check status on.

        Returns (Tuple[bool, bool, bool]):
            Indicates whether a certain state is true, (favorite, friend, blocked)

        """
        archive = self.facade.storage.vault.archive
        # def check():
        #    """Check the states."""
        #    favorites = await archive.islink(self.PATH_FAVORITES[0] + str(eid))
        #    friends = await archive.islink(self.PATH_FRIENDS[0] + str(eid))
        #    blocked = await archive.islink(self.PATH_BLOCKED[0] + str(eid))
        #    return favorites, friends, blocked
        # return await archive.execute(check)

        favorites = await archive.islink(self.PATH_FAVORITES[0] + str(eid))
        friends = await archive.islink(self.PATH_FRIENDS[0] + str(eid))
        blocked = await archive.islink(self.PATH_BLOCKED[0] + str(eid))
        return favorites, friends, blocked

    async def load_blocked(self) -> Set[Tuple[str, uuid.UUID]]:
        """Load a list of all blocked entities.

        Returns (List[Tuple[str, uuid.UUID]]):
            List of tuples with portfolio path and ID.

        """
        return await self.__load_contacts(self.PATH_BLOCKED[0] + "*")

    async def block(self, *entities: uuid.UUID) -> bool:
        """Put entities in the blocked category.

        This method will unfriend and unfavorite the entities.

        Args:
            *entities (uuid.UUID):
                Argument list of entities.

        Returns (bool):
            True on success.

        """
        archive = self.facade.storage.vault.archive
        async def do_block(eid):
            """Unfavorite, unfriend and block entity.

            Args:
                eid (uuid.UUID):
                    Entity ID to block.
            """
            is_link = await archive.islink(self.PATH_FAVORITES[0] + str(eid))
            if is_link:
                await self.__unlink(self.PATH_FAVORITES[0], eid)
            is_link = await archive.islink(self.PATH_FRIENDS[0] + str(eid))
            if is_link:
                await self.__unlink(self.PATH_FRIENDS[0], eid)
            is_link = await archive.islink(self.PATH_ALL[0] + str(eid))
            if is_link:
                await self.__unlink(self.PATH_ALL[0], eid)
            is_link = await archive.islink(self.PATH_BLOCKED[0] + str(eid))
            if not is_link:
                await self.__link(self.PATH_BLOCKED[0], eid)

        return await self.gather(*[do_block(entity) for entity in entities])

    async def unblock(self, *entities: uuid.UUID) -> bool:
        """Remove entities in the blocked category.

        Args:
            *entities (uuid.UUID):
                Argument list of entities.

        Returns (bool):
            True on success.

        """
        archive = self.facade.storage.vault.archive
        async def do_unblock(eid):
            """Unblock entity.

            Args:
                eid (uuid.UUID):
                    Entity ID to unblock.
            """
            is_link = await archive.islink(self.PATH_BLOCKED[0] + str(eid))
            if is_link:
                await self.__unlink(self.PATH_BLOCKED[0], eid)
            is_link = await archive.islink(self.PATH_ALL[0] + str(eid))
            if not is_link:
                await self.__link(self.PATH_ALL[0], eid)

        return await self.gather(*[do_unblock(entity) for entity in entities])

    async def load_friends(self) -> Set[Tuple[str, uuid.UUID]]:
        """Load a list of all friends.

        Returns (List[Tuple[str, uuid.UUID]]):
            List of tuples with portfolio path and ID.

        """
        return await self.__load_contacts(self.PATH_FRIENDS[0] + "*")

    async def friend(self, *entities: uuid.UUID) -> bool:
        """Put entities in the friends category.

        This method will unblock.

        Args:
            *entities (uuid.UUID):
                Argument list of entities.

        Returns (bool):
            True on success.

        """
        archive = self.facade.storage.vault.archive
        async def do_friend(eid):
            """Friend entity.

            Args:
                eid (uuid.UUID):
                    Entity ID to friend.
            """
            is_link = await archive.islink(self.PATH_BLOCKED[0] + str(eid))
            if is_link:
                await self.__unlink(self.PATH_BLOCKED[0], eid)
            is_link = await archive.islink(self.PATH_FRIENDS[0] + str(eid))
            if not is_link:
                await self.__link(self.PATH_FRIENDS[0], eid)
            is_link = await archive.islink(self.PATH_ALL[0] + str(eid))
            if not is_link:
                await self.__link(self.PATH_ALL[0], eid)

        return await self.gather(*[do_friend(entity) for entity in entities])

    async def unfriend(self, *entities: uuid.UUID) -> bool:
        """Remove entities in the friends category.

        Args:
            *entities (uuid.UUID):
                Argument list of entities.

        Returns (bool):
            True on success.

        """
        archive = self.facade.storage.vault.archive
        async def do_unfriend(eid):
            """Unfriend entity.

            Args:
                eid (uuid.UUID):
                    Entity ID to unfriend.
            """
            is_link = await archive.islink(self.PATH_FRIENDS[0] + str(eid))
            if is_link:
                await self.__unlink(self.PATH_FRIENDS[0], eid)

        return await self.gather(*[do_unfriend(entity) for entity in entities])

    async def load_favorites(self) -> Set[Tuple[str, uuid.UUID]]:
        """Load a list of all favorites.

        Returns (List[Tuple[str, uuid.UUID]]):
            List of tuples with portfolio path and ID.

        """
        return await self.__load_contacts(self.PATH_FAVORITES[0] + "*")

    async def favorite(self, *entities: uuid.UUID) -> bool:
        """Put entities in the favorite category.

        Args:
            *entities (uuid.UUID):
                Argument list of entities.

        Returns (bool):
            True on success.

        """
        archive = self.facade.storage.vault.archive
        async def do_favorite(eid):
            """Favorite entity.

            Args:
                eid (uuid.UUID):
                    Entity ID to favorite.
            """
            is_link = await archive.islink(self.PATH_BLOCKED[0] + str(eid))
            if is_link:
                await self.__unlink(self.PATH_BLOCKED[0], eid)
            is_link = await archive.islink(self.PATH_FAVORITES[0] + str(eid))
            if not is_link:
                await self.__link(self.PATH_FAVORITES[0], eid)
            is_link = await archive.islink(self.PATH_ALL[0] + str(eid))
            if not is_link:
                await self.__link(self.PATH_ALL[0], eid)

        return await self.gather(*[do_favorite(entity) for entity in entities])

    async def unfavorite(self, *entities: uuid.UUID) -> bool:
        """Remove entities in the favorite category.

        Args:
            *entities (uuid.UUID):
                Argument list of entities.

        Returns (bool):
            True on success.

        """
        archive = self.facade.storage.vault.archive
        async def do_unfavorite(eid):
            """Unfavorite entity.

            Args:
                eid (uuid.UUID):
                    Entity ID to unfavorite.
            """
            is_link = await archive.islink(self.PATH_FAVORITES[0] + str(eid))
            if is_link:
                await self.__unlink(self.PATH_FAVORITES[0], eid)

        return await self.gather(*[do_unfavorite(entity) for entity in entities])

    async def remove(self, *entities: uuid.UUID) -> bool:
        """Remove all links to old portfolios.

        Args:
            *entities (uuid.UUID):
                Argument list of entities.

        Returns (bool):
            True on success.

        """
        archive = self.facade.storage.vault.archive
        async def do_remove(eid):
            """Totally remove an entity from contacts.

            Args:
                eid (uuid.UUID):
                    Entity ID to remove.
            """
            is_link = await archive.islink(self.PATH_FAVORITES[0] + str(eid))
            if is_link:
                await self.__unlink(self.PATH_FAVORITES[0], eid)
            is_link = await archive.islink(self.PATH_FRIENDS[0] + str(eid))
            if is_link:
                await self.__unlink(self.PATH_FRIENDS[0], eid)
            is_link = await archive.islink(self.PATH_ALL[0] + str(eid))
            if is_link:
                await self.__unlink(self.PATH_ALL[0], eid)
            is_link = await archive.islink(self.PATH_BLOCKED[0] + str(eid))
            if is_link:
                await self.__unlink(self.PATH_BLOCKED[0], eid)

        return await self.gather(*[do_remove(entity) for entity in entities])
