# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Address fields internationalization."""


generic1 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.postcode} {a.town or a.city or a.village} || || {a.county or a.state}\n{a.country}""")  # noqa E501
generic2 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.village or a.city or a.town or a.county} {a.postcode}\n{a.country or a.state}""")  # noqa E501
generic3 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.postcode} {a.city or a.town or a.village or a.state}\n{a.country}""")  # noqa E501
generic4 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.city or a.town or a.state_district or a.village or a.suburb or a.county}, {a.state_code or a.state} {a.postcode}\n{a.country}""")  # noqa E501
generic6 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.city or a.town or a.village}\n{a.county}\n{a.country}""")  # noqa E501
generic7 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.city or a.town or a.village}, {a.postcode}\n{a.country}""")  # noqa E501
generic8 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.road}, {a.house_number}\n{a.postcode} {a.city or a.town or a.village} {a.county_code or a.county}\n{a.country}""")  # noqa E501
generic9 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.suburb or a.city_district or a.state_district}\n{a.postcode} {a.city or a.town or a.village or a.state}\n{a.country}""")  # noqa E501
generic10 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.suburb}\n{a.city or a.town or a.village}\n{a.state}\n{a.country}\n{a.postcode}""")  # noqa E501
generic11 = (lambda attention, a: f"""{a.country}\n{a.state}\n{a.postcode} {a.city or a.town or a.village}\n{a.suburb}\n{a.road}, {a.house_number}\n{a.house}\n{attention}""")  # noqa E501
generic12 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number}, {a.road}\n{a.suburb or a.city_district or a.state_district}\n{a.city or a.town or a.village} - {a.postcode}\n{a.state}\n{a.country}""")  # noqa E501
generic13 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city or a.town or a.state_district or a.village or a.region} {a.state_code or a.state} {a.postcode}\n{a.country}""")  # noqa E501
generic14 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.postcode} {a.city or a.town or a.village or a.state_district}\n{a.state}\n{a.country}""")  # noqa E501
generic15 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.road}, {a.house_number}\n{a.postcode} {a.city or a.town or a.village or a.state or a.county}\n{a.country}""")  # noqa E501
generic16 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.city or a.town or a.village or a.county or a.state_district or a.state}\n{a.country}""")  # noqa E501
generic17 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.city or a.town or a.village or a.county or a.state_district or a.state}\n{a.country}""")  # noqa E501
generic18 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number}, {a.road}\n{a.city or a.town or a.village or a.suburb or a.city_district or a.neighbourhood or a.state}\n{a.country}""")  # noqa E501
generic20 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.city or a.town or a.village} {a.postcode}\n{a.country}""")  # noqa E501
generic21 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.city or a.town or a.village or a.state}\n{a.country}""")  # noqa E501
generic22 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number}, {a.road}\n{a.postcode} {a.city or a.town or a.village or a.state}\n{a.country}""")  # noqa E501

fallback3 = (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.suburb}\n{a.city or a.town or a.village}\n{a.county}\n{a.state}\n{a.country}""")  # noqa E501


FORMAT = {
    'AD': generic3,
    'AE': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.city or a.town or a.village}\n{a.state_district or a.state}\n{a.country}"""),  # noqa E501
    'AF': generic21,
    'AG': generic16,
    'AI': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.city or a.town or a.village}\n{a.postcode} {a.country}"""),  # noqa E501
    'AL': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.postcode} {a.city or a.town or a.state_district or a.village}\n{a.country}"""),  # noqa E501
    'AM': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.postcode}\n{a.city or a.town or a.village}\n{a.state_district or a.state}\n{a.country}"""),  # noqa E501
    'AO': generic7,
    'AQ': (lambda attention, a: f"""{attention}\n{a.house}\n{a.city or a.town or a.village}\n{a.country or a.continent}"""),  # noqa E501
    'AR': generic9,
    'AS': generic4,
    'AT': generic9,
    'AU': generic13,
    'AW': generic17,
    'AX': generic1,
    'AZ': generic3,
    'BA': generic1,
    'BB': generic16,
    'BD': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city_district or a.state_district}\n{a.city or a.town or a.village} - {a.postcode}\n{a.country}"""),  # noqa E501
    'BE': generic1,
    'BF': generic6,
    'BG': generic9,
    'BH': generic2,
    'BI': generic17,
    'BJ': generic18,
    'BL': generic3,
    'BM': generic2,
    'BN': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number}, {a.road}\n{a.city or a.town or a.village}\n{a.county or a.state_district or a.state} {a.postcode}\n{a.country}"""),  # noqa E501
    'BO': generic17,
    'BQ': generic1,
    'BR': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road}, {a.house_number}\n{a.city or a.town or a.state_district or a.village} - {a.state_code or a.state}\n{a.postcode}\n{a.country}"""),  # noqa E501
    'BS': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.city or a.town or a.village}\n{a.county}\n{a.country}"""),  # noqa E501
    'BT': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}, {a.house}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.city or a.town or a.village or a.state} {a.postcode}\n{a.country}"""),  # noqa E501
    'BV': generic1,
    'BW': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.city or a.town or a.village}\n{a.country}"""),  # noqa E501
    'BY': generic11,
    'BZ': generic16,
    'CA': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road or a.suburb}\n{a.city or a.town or a.state_district or a.village}, {a.state_code or a.state} {a.postcode}\n{a.country}"""),  # noqa E501
    'CC': generic3,
    'CD': generic18,
    'CF': generic17,
    'CG': generic18,
    'CH': generic1,
    'CI': generic16,
    'CK': generic16,
    'CL': generic1,
    'CM': generic17,
    'CN': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.county}\n{a.postcode} {a.state_code or a.state or a.city or a.town or a.state_district or a.village}\n{a.country}"""),  # noqa E501
    'CN_en': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.county}\n{a.postcode} {a.state_code or a.state or a.city or a.town or a.state_district or a.village}\n{a.country}"""),  # noqa E501
    'CN_zh': (lambda attention, a: f"""{a.country}\n{a.postcode}\n{a.state_code or a.state}\n{a.state_district or a.county}\n{a.city or a.town or a.village}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.road}\n{a.house_number}\n{a.house}\n{attention}"""),  # noqa E501
    'CO': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.postcode} {a.city or a.town or a.state_district or a.village}, {a.state_code or a.state}\n{a.country}"""),  # noqa E501
    'CR': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.state}, {a.city or a.town or a.state_district or a.village}, {a.suburb or a.city_district or a.neighbourhood}\n{a.postcode} {a.country}"""),  # noqa E501
    'CU': generic7,
    'CV': generic1,
    'CW': generic17,
    'CX': generic3,
    'CY': generic1,
    'CZ': generic1,
    'DE': generic1,
    'DJ': generic16,
    'DK': generic1,
    'DM': generic16,
    'DO': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.city or a.town or a.village}, {a.state}\n{a.postcode}\n{a.country}"""),  # noqa E501
    'DZ': generic3,
    'EC': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.postcode}\n{a.city or a.town or a.state_district or a.village}\n{a.country}"""),  # noqa E501
    'EE': generic1,
    'EG': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.city or a.town or a.village}\n{a.postcode}\n{a.country}"""),  # noqa E501
    'EH': generic17,
    'ER': generic17,
    'ES': generic15,
    'ET': generic1,
    'FI': generic1,
    'FJ': generic16,
    'FK': generic2,
    'FM': generic4,
    'FO': generic1,
    'FR': generic3,
    'GA': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city_district or a.neighbourhood or a.village}\n{a.city or a.town or a.county or a.state_district or a.state}\n{a.country}"""),  # noqa E501
    'GB': generic2,
    'GD': generic17,
    'GE': generic1,
    'GF': generic3,
    'GG': generic2,
    'GH': generic16,
    'GI': generic16,
    'GL': generic1,
    'GM': generic16,
    'GN': generic14,
    'GP': generic3,
    'GQ': generic17,
    'GR': generic1,
    'GS': generic2,
    'GT': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.postcode}-{a.city or a.town or a.village or a.state}\n{a.country}"""),  # noqa E501
    'GU': generic4,
    'GW': generic1,
    'GY': generic16,
    'HK': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.state_district}\n{a.state}"""),  # noqa E501
    'HK_en': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.state_district}\n{a.state}\n{a.country}"""),  # noqa E501
    'HK_zh': (lambda attention, a: f"""{a.country}\n{a.state}\n{a.state_district}\n{a.road}\n{a.house_number}\n{a.house}\n{attention}"""),  # noqa E501
    'HM': generic3,
    'HN': generic1,
    'HR': generic1,
    'HT': generic1,
    'HU': (lambda attention, a: f"""{attention}\n{a.house}\n{a.city or a.town or a.village}\n{a.road} {a.house_number}\n{a.postcode}\n{a.country}"""),  # noqa E501
    'ID': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.city or a.town or a.village} {a.postcode}\n{a.state}\n{a.country}"""),  # noqa E501
    'IE': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.city or a.town or a.village}\n{a.county}\n{a.country}"""),  # noqa E501
    'IL': generic1,
    'IM': generic2,
    'IN': generic12,
    'IO': generic2,
    'IQ': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.neighbourhood or a.city_district or a.suburb}\n{a.road}\n{a.city or a.town or a.state or a.village}\n{a.postcode}\n{a.country}"""),  # noqa E501
    'IR': (lambda attention, a: f"""{attention}\n{a.house}\n{a.city or a.town or a.village}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.road}\n{a.house_number}\n{a.province or a.state}\n{a.postcode}\n{a.country}"""),  # noqa E501
    'IR_en': (lambda attention, a: f"""{attention}\n{a.house}\n{a.city or a.town or a.village}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.road}\n{a.house_number}\n{a.province or a.state}\n{a.postcode}\n{a.country}"""),  # noqa E501
    'IR_fa': (lambda attention, a: f"""{a.country}\n{a.state or a.province}\n{a.city or a.town or a.village}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.road}\n{a.house_number}\n{a.house}\n{attention}\n{a.postcode}"""),  # noqa E501
    'IS': generic1,
    'IT': generic8,
    'JE': generic2,
    'JM': generic20,
    'JO': generic1,
    'JP': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.city or a.town or a.village}, {a.state or a.state_district} {a.postcode}\n{a.country}"""),  # noqa E501
    'JP_en': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.city or a.town or a.village}, {a.state or a.state_district} {a.postcode}\n{a.country}"""),  # noqa E501
    'JP_ja': (lambda attention, a: f"""{a.country}\n{a.postcode}\n{a.state or a.state_district}\n{a.city or a.town or a.village}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.road}\n{a.house_number}\n{a.house}\n{attention}"""),  # noqa E501
    'KE': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.city or a.town or a.state or a.village}\n{a.postcode}\n{a.country}"""),  # noqa E501
    'KG': generic11,
    'KH': generic20,
    'KI': generic17,
    'KM': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.city or a.town or a.village}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.country}"""),  # noqa E501
    'KN': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.city or a.town or a.village}, {a.state or a.island}\n{a.country}"""),  # noqa E501
    'KP': generic21,
    'KR': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city_district or a.neighbourhood}, {a.city or a.town or a.village}, {a.state} {a.postcode}\n{a.country}"""),  # noqa E501
    'KR_en': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city_district or a.neighbourhood}, {a.city or a.town or a.village}, {a.state} {a.postcode}\n{a.country}"""),  # noqa E501
    'KR_ko': (lambda attention, a: f"""{a.country}\n{a.state}\n{a.city or a.town or a.village}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.road}\n{a.house_number}\n{a.house}\n{attention}\n{a.postcode}"""),  # noqa E501
    'KW': (lambda attention, a: f"""{attention}\n{a.house}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.road}\n{a.house_number} {a.house}\n{a.postcode} {a.city or a.town or a.village}\n{a.country}"""),  # noqa E501
    'KY': generic2,
    'KZ': generic11,
    'LA': generic22,
    'LB': generic2,
    'LC': generic17,
    'LI': generic1,
    'LK': generic20,
    'LR': generic1,
    'LS': generic2,
    'LT': generic1,
    'LU': generic3,
    'LV': generic7,
    'LY': generic17,
    'MA': generic3,
    'MC': generic3,
    'MD': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road}, {a.house_number}\n{a.postcode} {a.city or a.town or a.village or a.state}\n{a.country}"""),  # noqa E501
    'ME': generic1,
    'MF': generic3,
    'MG': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.postcode} {a.city or a.town or a.village}\n{a.country}"""),  # noqa E501
    'MH': generic4,
    'MK': generic1,
    'ML': generic17,
    'MM': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.city or a.town or a.village or a.state}, {a.postcode}\n{a.country}"""),  # noqa E501
    'MN': (lambda attention, a: f"""{attention}\n{a.house}\n{a.city_district}\n{a.suburb or a.neighbourhood}\n{a.road}\n{a.house_number}\n{a.postcode}\n{a.city or a.town or a.village}\n{a.country}"""),  # noqa E501
    'MO': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.suburb or a.village or a.state_district}\n{a.country}"""),  # noqa E501
    'MO_pt': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.suburb or a.village or a.state_district}\n{a.country}"""),  # noqa E501
    'MO_zh': (lambda attention, a: f"""{a.country}\n{a.suburb or a.village or a.state_district}\n{a.road}\n{a.house_number}\n{a.house}\n{attention}"""),  # noqa E501
    'MP': generic4,
    'MQ': generic3,
    'MR': generic18,
    'MS': generic16,
    'MT': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.city or a.town or a.suburb or a.village}\n{a.postcode}\n{a.country}"""),  # noqa E501
    'MU': generic18,
    'MV': generic2,
    'MW': generic16,
    'MX': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.postcode} {a.city or a.town or a.state_district or a.village}, {a.state_code or a.state}\n{a.country}"""),  # noqa E501
    'MY': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.postcode} {a.city or a.town or a.village}\n{a.state}\n{a.country}"""),  # noqa E501
    'MZ': generic15,
    'NA': generic2,
    'NC': generic3,
    'NE': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number}\n{a.road}\n{a.city or a.town or a.village}\n{a.country}"""),  # noqa E501
    'NF': generic3,
    'NG': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.city or a.town or a.village} {a.postcode}\n{a.state}\n{a.country}"""),  # noqa E501
    'NI': generic21,
    'NL': generic1,
    'NO': generic1,
    'NP': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.suburb or a.neighbourhood or a.city}\n{a.county or a.state_district or a.state} {a.postcode}\n{a.country}"""),  # noqa E501
    'NR': generic16,
    'NU': generic16,
    'NZ': generic20,
    'OM': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.postcode}\n{a.city or a.town or a.state_district or a.village}\n{a.state}\n{a.country}"""),  # noqa E501
    'PA': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.postcode}\n{a.city or a.town or a.state_district or a.village}\n{a.state}\n{a.country}"""),  # noqa E501
    'PE': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.city or a.town or a.village} {a.postcode}\n{a.country}"""),  # noqa E501
    'PF': generic3,
    'PG': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.city or a.town or a.village} {a.postcode} {a.state}\n{a.country}"""),  # noqa E501
    'PH': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.city or a.town or a.village or a.suburb or a.state_district}\n{a.postcode} {a.state}\n{a.country}"""),  # noqa E501
    'PK': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.city or a.town or a.village or a.state} {a.postcode}\n{a.country}"""),  # noqa E501
    'PL': generic1,
    'PM': generic3,
    'PN': (lambda attention, a: f"""{attention}\n{a.house}\n{a.city or a.town or a.island}\n{a.country}"""),  # noqa E501
    'PR': generic4,
    'PS': generic1,
    'PT': generic1,
    'PW': generic1,
    'PY': generic1,
    'QA': generic17,
    'RE': generic3,
    'RO': generic1,
    'RS': generic1,
    'RU': generic10,
    'RW': generic16,
    'SA': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}, {a.village or a.city_district or a.suburb or a.neighbourhood}\n{a.city or a.town or a.state_district} {a.postcode}\n{a.country}"""),  # noqa E501
    'SB': generic17,
    'SC': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.city or a.town or a.village or a.island}\n{a.island}\n{a.country}"""),  # noqa E501
    'SD': generic1,
    'SE': generic1,
    'SG': generic2,
    'SH': generic2,
    'SI': generic1,
    'SJ': generic1,
    'SK': generic1,
    'SL': generic16,
    'SM': generic8,
    'SN': generic3,
    'SO': generic21,
    'SR': generic21,
    'SS': generic17,
    'ST': generic17,
    'SV': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.postcode} - {a.city or a.town or a.village}\n{a.state}\n{a.country}"""),  # noqa E501
    'SX': generic17,
    'SY': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road}, {a.house_number}\n{a.village or a.city_district or a.neighbourhood or a.suburb}\n{a.postcode} {a.city or a.town or a.state_district or a.state}\n{a.country}"""),  # noqa E501
    'SZ': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.city or a.town or a.village or a.state}\n{a.postcode}\n{a.country}"""),  # noqa E501
    'TC': generic2,
    'TD': generic21,
    'TF': generic3,
    'TG': generic18,
    'TH': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.village}\n{a.road}\n{a.neighbourhood or a.city or a.town}, {a.suburb or a.city_district or a.state_district}\n{a.state} {a.postcode}\n{a.country}"""),  # noqa E501
    'TJ': generic1,
    'TK': generic20,
    'TL': generic17,
    'TM': generic22,
    'TN': generic3,
    'TO': generic16,
    'TR': generic1,
    'TT': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city_district or a.state_district}\n{a.city or a.town or a.state_district or a.village}, {a.postcode}\n{a.country}"""),  # noqa E501
    'TV': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.city or a.town or a.village}\n{a.county or a.state_district or a.state or a.island}\n{a.country}"""),  # noqa E501
    'TW': generic20,
    'TW_en': generic20,
    'TW_zh': (lambda attention, a: f"""{a.country}\n{a.postcode}\n{a.city or a.town or a.village}\n{a.city_district}\n{a.suburb or a.city_district or a.neighbourhood}\n{a.road}\n{a.house_number}\n{a.house}\n{attention}"""),  # noqa E501
    'TZ': generic14,
    'UA': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road}, {a.house_number}\n{a.suburb or a.city_district or a.state_district}\n{a.city or a.town or a.village or a.state}\n{a.postcode}\n{a.country}"""),  # noqa E501
    'UG': generic16,
    'UM': generic4,
    'US': generic4,
    'UY': generic1,
    'UZ': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.city or a.town or a.village}\n{a.state or a.state_district}\n{a.country}\n{a.postcode}"""),  # noqa E501
    'VA': generic8,
    'VC': generic17,
    'VE': (lambda attention, a: f"""{attention}\n{a.house}\n{a.road} {a.house_number}\n{a.city or a.town or a.state_district or a.village} {a.postcode}, {a.state_code or a.state}\n{a.country}"""),  # noqa E501
    'VG': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.city or a.town or a.village}, {a.island}\n{a.country}, {a.postcode}"""),  # noqa E501
    'VI': generic4,
    'VN': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number}, {a.road}\n{a.suburb or a.city_district or a.neighbourhood}, {a.city or a.town or a.state_district or a.village}\n{a.state} {a.postcode}\n{a.country}"""),  # noqa E501
    'VU': generic17,
    'WF': generic3,
    'WS': generic17,
    'YE': generic18,
    'YT': generic3,
    'ZA': (lambda attention, a: f"""{attention}\n{a.house}\n{a.house_number} {a.road}\n{a.suburb or a.city_district or a.state_district}\n{a.city or a.town or a.village or a.state}\n{a.postcode}\n{a.country}"""),  # noqa E501
    'ZM': generic3,
    'ZW': generic16,
 }
