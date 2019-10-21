# Angelos / Logo

<img align="left" height="256" src="https://github.com/kristoffer-paulsson/angelos/blob/master/art/angelos.png"/>

Ἄγγελος is a safe messenger system. Angelos means "Carrier of a divine message."

Λόγῳ is a safe messenger client. Logo means "Reason, matter, statement, remark, saying, Word."

## Purpose

In many places of the world Christians are lacking the freedom to practice their faith and express their beliefs. In some parts of the world Christians risk their lives to meet in the homes. In other countries they are being limited in what they are allowed to believe, or being discriminated for not submitting to a repressive regime. This kind of laws are about to come through in western countries that supposedly have religious freedom.

The believers have their computers monitored, their phones are being eavesdropped. Their neighbors might report what they think are going on to the authorities, just for basically practicing their faith. As of today social media can not be trusted to guarantee your freedom to practice your faith. The media corporations are surrendering to the regimes, where their users live, or is biased themselves.

Today there is a need for a platform that is neutral, decentralized and secure, so that PoF (Persons of Faith) don't have to worry about being spied upon, being monitored, harassed or directly persecuted. What we want to do is to provide a software platform made up of a Client mobile and desktop app, and a Server software to handle safe communication.

## Solution

The solution is that Christians and the congregations they are part of in each city, should be enabled to communicate securely. For that we need a software platform that is neutral, decentralized and secure.

* Neutral - By making the platform NOT hierarchical, but rather peer-to-peer we can guarantee that no-one can take total control over the system, it is a system based on trust and credibility.
* Decentralized - The platform will be engineered in such a way, that there is no central authority, but instead a number of decentralized networks that can be interconnected. That means that no rouge entity can shut down the whole system, also corrupt networks can be disconnected.
* Secure - All communication between client and servers, and networks are encrypted. All storage and databases on the filesystems are encrypted, so that no rouge entity can spy on the users. Also each user has a uniqe encryption key to sign and encrypt all communication. This guarantees that all communication is private and that the senders are verified.

With such a social platform persons of faith should be able to communicate with each other. Being able to plan where to celebrate their common faith without interruption. And being enabled to help and support each other in though environments.

## Goal

First we need to understand what this is. The platform is called Angelos, and the app is called Logo. This is the software platform that will be free and available as open source.

The goal of this project is to design and develop a server and app communications platform. This social media platform is targeted towards smartphones, tablets, desktop computers and the server software to be installable on Linux and windows servers.

## Technology

The platform is mainly being developed in Python 3.7~ and relies heavily on the SSH protocol and cryptography from (NaCl) libsodium. App development is mainly done in KivyMD. The communication system builds heavily on Peer-2-peer replication.

## How to use

Assume that some believers living in a city somewhere with or without persecution, wants to be able to communicate and organize securely. They decide to download the Angelos server and install it on a server hotel connected to the internet. They also download the app and installs it on their smartphones and computers. They logon to the local Angelos server and verify each others credibility, which is their social trust to each other in that local network. More people joins the Christian network, they download the app and connect to the current server. When they verify with already trusted persons, the services on the platform becomes available for them. All app-to-server communication is encrypted, all data saved on the apps is encrypted, also the servers. After some time one of the believers realize that Christians in the neighbor city also runs an Angelos city network, they decide to interconnect their networks, now christians in both cities can communicate securely with each other. After some time there is a nationwide use of the Angelos system interconnected between cities. If persecution is starting, anyone can report that to other interconnected city churches. There is no risk that information can be stolen by rouge entities.

## Setup development environment
Download source tree from Github.
> git clone git://github.com/kristoffer-paulsson/angelos.git
> cd angelos

Setup a virtual environment with Python 3.
> virtualenv -p /usr/bin/python3.7 venv

Install required packages.
> pip install -r requirements.txt

Build one of the targets. (angelos/logo/ar7)
> make &lt;target&gt;

Run the compiled target.
> &lt;target&gt;

## external access

On Debian you must open the ports that will be used by angelos. If you already have a SSH daemon installed it has to be reconfigured to not run on port 22. As sudo user do this.

> iptables -A INPUT -p tcp --dport 22 --jump ACCEPT
>
> iptables -A INPUT -p tcp --dport 3 --jump ACCEPT
>
> iptables -A INPUT -p tcp --dport 4 --jump ACCEPT
>
> iptables -A INPUT -p tcp --dport 5 --jump ACCEPT
>
> iptables-save

Then angelos must be started with the option to listen to any

> angelos -l any
