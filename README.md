# Angelos / Logo

<img height="256" src="https://angelos-project.com/images/angelos.png"/>

Ἄγγελος is a safe messenger system. Angelos means "Carrier of a divine message."<br />
Λόγῳ is a safe messenger client. Logo means "Word with an intent."

[![Codacy Badge](https://app.codacy.com/project/badge/Grade/ce492ea15eb2477caac227d422c3aae4)](https://www.codacy.com/gh/kristoffer-paulsson/angelos/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=kristoffer-paulsson/angelos&amp;utm_campaign=Badge_Grade)
[![Build Status](https://travis-ci.com/kristoffer-paulsson/angelos.svg?branch=master)](https://travis-ci.com/kristoffer-paulsson/angelos)

## Online presence

Visit us at [angelos-project.com](https://angelos-project.com).<br />
Talk to us on our [discord server](https://discord.gg/TPx65rT).

## Technology

Mainly compiled Python for safety reasons.
All information is encrypted on harddrive as well on the network using [libsodium](https://libsodium.gitbook.io/doc/) (NaCl).
Python 3.7 is the preferred version.
User interface follows [Material Design](https://material.io).

## Development
Download source tree from Github.

_On macOS make sure to run "Install Certificates.command" once in order for download to work._

> &gt; pip list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip install -U
>
> &gt; git clone git://github.com/kristoffer-paulsson/angelos.git
> 
> &gt; cd angelos
> 
> &gt; virtualenv -p /usr/bin/python3.7 venv
> 
> &gt; source venv/bin/activate
> 
> &gt; pip install -r requirements.txt
> 
> &gt; python setup.py develop
> 
> &gt; coverage run -m unittest  angelos-\*/test/test_\*

## Run in virtualenv

Start server inside a virtual environment.
> angelos-server/bin/angelos -l=localhost -p=1024 --root-dir=./dev_env/ --run-dir=./dev_env/ --state-dir=./dev_env/ --logs-dir=./dev_env/ --conf-dir=./dev_env/ &

Start the control admin client.
> angelos-ctl/bin/angelosctl 127.0.0.1 -p=1024 -s=a0d4968e2efb058b6f0091a4d5b21672c921e2aacfd6a3a1395deaa9a42c8418

