# Levels

The Angelos system is divided into levels, there are seven levels defined, each level is sectioned. Think of the levels as layers of an onion where level one is the innermost level and level seven the outermost layer. 

## 1Fields

Level 1 is the field level and the innermost layer and the most fundamental item inside an Angelos system. The F contains none, one or several pieces of data of a defined type and can be validated according to the policies applied to this level.

## 2Documents

Level 2 is the document level. A Document represents either an identity, certificate or message or another piece of data, composed of several fields. Documents can be validated according to policies appliad to its own and inner levels. Documents should always be cryptographically signed by an identity using its cryptographic

## 3Portfolios

Level 3 is the portfolio level. A Portfolio is a collection of documents related by identity ownership. The Portfolio must only have one identity Document to which all other documents belong. Portfolios has predefined configurations of documents depending on use, but can contain any number of documents necessary. All portfolios can be validated according to policies of its own level and inner levels. The configurations can be used for public or private purposes depending on needs, it is necessary to share the Portfolio in order to be able to interact with other 

## 4Facade

Level 4 is the facade level. The Facade is the front and gatekeeper of each installed Angelos instance. The job of the Facade is to provide a proven way of importing, exporting and interacting with other entities on a network of individuals garuanteeing the safety and integrity of its owner. Policies are applied and operations performed according to qualified standards and measures. 

## 5Nodes

Level 5 is the node level. A Node is a single device that the Angelos server or client software is installed on. However the Node information is kept on the inside of the Facade but representing the software and hardware level that interacts with other instances of Angelos on other devices but inside the same domain. Each Node is a member of a Domain.

## 6Domain

Level 6 is the domain level. A Domain is an abstract level representing a collection of one or several nodes that work for one and the same entity (individual or organisation). Nodes and Domain information is internal to the Portfolio of the Facades on each N

## 7Network

Level 7 is the network level. A Network is a representation of individuals or organizations that is offering a community for others to members of. Network Nodes are usually servers that other individuals Nodes (clients) can interact with for the purpose of communication.