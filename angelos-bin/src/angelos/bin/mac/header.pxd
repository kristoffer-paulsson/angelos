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
import binascii
import uuid

# https://stackoverflow.com/questions/933460/unique-hardware-id-in-mac-os-x


cdef extern from "MacTypes.h" nogil:
    ctypedef unsigned int UInt32
    ctypedef unsigned char Boolean

cdef extern from "mach/mach.h" nogil:
    ctypedef int mach_port_t

cdef extern from "mach/i386/kern_return.h" nogil:
    ctypedef int kern_return_t

cdef extern from "device/device_types.h" nogil:
    ctypedef char io_string_t[512]

cdef extern from "CoreFoundation/CFBase.h" nogil:
    ctypedef signed long CFIndex
    ctypedef void * CFTypeRef
    ctypedef void * CFStringRef
    ctypedef void * CFAllocatorRef
    ctypedef const CFAllocatorRef kCFAllocatorDefault
    void CFRelease(CFTypeRef cf)

cdef extern from "CoreFoundation/CFString.h" nogil:
    ctypedef UInt32 CFStringEncoding
    Boolean CFStringGetCString(CFStringRef theString, char *buffer, CFIndex bufferSize, CFStringEncoding encoding)

cdef extern from "IOKit/IOTypes.h" nogil:
    ctypedef UInt32 IOOptionBits
    ctypedef mach_port_t io_object_t
    ctypedef io_object_t io_registry_entry_t

cdef extern from "IOKit/IOKitLib.h" nogil:
    cdef const mach_port_t kIOMasterPortDefault
    io_registry_entry_t IORegistryEntryFromPath(mach_port_t masterPort, const io_string_t path)
    CFTypeRef IORegistryEntryCreateCFProperty(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options)
    kern_return_t IOObjectRelease(io_object_t object)


def get_platform_uuid() -> uuid.UUID:
    """Platform specific UUID for macOS."""
    cdef io_registry_entry_t io_registry_root
    cdef CFStringRef uuid_cf
    un = bytes(37)

    io_registry_root = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/")
    uuid_cf = <CFStringRef> IORegistryEntryCreateCFProperty(io_registry_root, <CFStringRef> b"IOPlatformUUID", NULL, 0)
    IOObjectRelease(io_registry_root)
    CFStringGetCString(uuid_cf, un, 0, 0)
    CFRelease(uuid_cf)

    return uuid.UUID(bytes=binascii.unhexlify(un[0:8]+un[9:13]+un[14:18]+un[19:23]+un[24:36]))
