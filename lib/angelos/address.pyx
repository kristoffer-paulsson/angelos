"""Address fields internationalization."""

FORMAT = (  # Format
    f'Address formatting string',
    (  # Row
        (  # Field
            '<field> (str)',
            '<fieldname> (str)',
            '<prefix> (str/None)',
            '<postfix> (str/None)',
            '<modifier> (func)',
            '<width_in_0.x> (float)'
        ),
    ),
)

SE = (  # Format
    "{'c/o '+co'//N' if co else ''}{'Box '+pobox+'//N' if pobox else street+' '+number+'//N'}{zip if zip else ''} {city if city else ''}{'//N'+country if country else ''}"  # noqa 501
    (  # Row
        (  # Field
            '<field> (str)',
            '<fieldname> (str)',
            '<prefix> (str/None)',
            '<postfix> (str/None)',
            '<modifier> (func)',
            '<width_in_0.x> (float)'
        ),
    ),
)

"""
5.1	Argentina
5.2	Australia
5.3	Austria
5.4	Bangladesh
5.5	Belarus
5.6	Belgium
5.7	Brazil
5.8	Canada
5.9	Chile
5.10	China
5.11	Croatia
5.12	Czech Republic
5.13	Denmark
5.14	Estonia
5.15	Finland
5.16	France
5.17	Germany
5.18	Greece
5.19	Hong Kong
5.20	Hungary
5.21	Iceland
5.22	India
5.23	Indonesia
5.24	Iran
5.25	Iraq
5.26	Ireland
5.27	Israel
5.28	Italy
5.29	Japan
5.30	South Korea
5.31	Latvia
5.32	Macau
5.33	Malaysia
5.34	Mexico
5.35	Netherlands
5.36	New Zealand
5.37	Norway
5.38	Oman
5.39	Pakistan
5.40	Peru
5.41	Philippines
5.42	Poland
5.43	Portugal
5.44	Qatar
5.45	Romania
5.46	Russia
5.47	Saudi Arabia
5.48	Serbia
5.49	Singapore
5.50	Slovakia
5.51	Slovenia
5.52	Spain
5.53	Sri Lanka
5.54	Sweden
5.55	Switzerland
5.56	Taiwan
5.57	Thailand
5.58	Turkey
5.59	Ukraine
5.60	United Arab Emirates
5.61	United Kingdom
5.62	United States
5.63	Vietnam
"""
