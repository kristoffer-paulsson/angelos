# cython: language_level=3
"""

Copyright (c) 2018-1019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


RSA keys for the boot and shell server."""

"""
This RSA key is the official private key of the server, it should either only
be used as a dummy under development or as a default key for installed but
unconfigured servers.
"""
SERVER_RSA_PRIVATE = """\
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAr35jVWyG3gjaQ735h8sBuJiJr/dWi9CfuDl0bdYlIaz1qUMa
pVlcPVEjH/ukVTOi8dme0dqPnO7za00/4BVrtsKqMXDhsrE+RhC6d8QWsk+Rf5Ym
c5Qjmhio0aqC7gDmDAT0bQytVM2seOVg22dqXZiO00pIB9lM/KeLJxLczQeS8gfD
iBdZI1Kb5ul90H6v0lklb6DyAUostiHdVPoFOAlFwgKXzgBqWMHj4fYApeNDSEuE
yYDKzxkTqU5Hgs+4dGBnjrBfhfLjM21GVBTgPXHr66IKtZ0FCEPdT+xGmdU6ni70
6SZ78NB+H49CYe8U4vJ007fjKsRPtvoFcdLzMQIDAQABAoIBAEvfSrbt+skX7rWG
9tD8tbvHRw/q0WIVSlhtjqbGBLuweW06c9S086oW4Ca9tuiXMIV7Xqy/34Mr09W6
SjlpSW50bvx9HzcQZioIpXWOM3nX6MHOesVRcKr4qlQrcfvQK6VapwpWhsG5Qi3q
jZuN9HCOuoEjBk1OZ3h8Py8fepKxUW1CQ5mEeub16Wwg17hltQliwLLfHUCt/Mu5
/u91IMiJGZYPZTyPFNiP42hNKz15ldRbwOgu5pA+BtyZ+DgfjqgZ2lY+eNucucZW
Cn9SwX1RFmtI3p8HHYHFDpfPtY2G5tI1oiV/bUbI/PQqaDRpyWliG+TD+5rrz1eQ
xpV8tHkCgYEA6ezQKOyoWjLO5/lkErlui9AOqIBW5hRYPh+2wv2By7LK7LDj0TdE
DKBjcYO31/LU2H5Ms+WI4T2hH5bBJZnxrTOCMgJxCuLX0wHn+eo/6s7xzpnwG77R
+ygGfU3wwdGhhAJFHOHS2uYLUt7LvMWgHLweB3Lb6tSLsAZqEYrEeQcCgYEAwA37
6RHdXVfVEb9r+hYOaTnSjjs0JPkBNL0QNDkcdlRiBG8O4V6EQ3xMDTWrirTIma5/
EQpHZXJrL5cEIphwZ71Up7bZeisIgr+piio2rMC259idAlFveOQaBsmZ0a1vnN35
TwdLXS/LJwzfPPqrwt7J05yHLneC/4oboj26PAcCgYEAksaNQfBkHdxdaL5ZpUoG
a+GLIP0OCWVgjPJXOXfZFhfELck72M1FfGqymsob83qhRInS1NnEDhgeXfS4kkBK
nPOB0KEpjrwQ0YwTowLxQgLBRHHgb3hGxsExeTQLSYGgR3UpKlsjc0f+eOvkiDi0
IvOCIAhYprrgPv13VjRs3McCgYAPf9FpsNhllRYL9Z/YMfl9wn3cnqiJp1LSl8N8
A3PplMvIQdI4m/EepSRaGI+8hPR/epakoGi8pixCTfS2egjwRlZTpq0Mb/ai3qbn
EJsS/AaG1XNuYXYWkooLLC/uvQl55mwdVaBeZ+IER8SoXi6IboRpQIOkW17GErZC
NKsX9wKBgQCiDMUwyHB294f08/s1HHHc8taNclgHLFREKN7DVvTAxeWyfcOlYd9O
8Htbs0Nwy4yfaP6d76Uw2YtWu3InRyJfea6vPag6/nelnu7p040B8zLCXm/kB/EP
wubsVeAiD5NWk6Mb+pwT2hwybTRoWCdA+B0nZtocEGmQRib/jW6BZA==
-----END RSA PRIVATE KEY-----
"""

"""
This RSA key is the official public key of the server, it should either only
be used as a dummy under development or as a default key for installed but
unconfigured servers.
"""
SERVER_RSA_PUBLIC = """ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCvfmNVbIbeCNpDvfm\
HywG4mImv91aL0J+4OXRt1iUhrPWpQxqlWVw9USMf+6RVM6Lx2Z7R2o+c7vNrTT/gFWu2wqoxcOGys\
T5GELp3xBayT5F/liZzlCOaGKjRqoLuAOYMBPRtDK1Uzax45WDbZ2pdmI7TSkgH2Uz8p4snEtzNB5L\
yB8OIF1kjUpvm6X3Qfq/SWSVvoPIBSiy2Id1U+gU4CUXCApfOAGpYwePh9gCl40NIS4TJgMrPGROpT\
keCz7h0YGeOsF+F8uMzbUZUFOA9cevrogq1nQUIQ91P7EaZ1TqeLvTpJnvw0H4fj0Jh7xTi8nTTt+M\
qxE+2+gVx0vMx"""
