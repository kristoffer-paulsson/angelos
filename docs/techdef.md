# Technical definitions

The Angelos system contains a certain number of technical terms that needs an explanation.

1. Document:
   A data structure based on several fields representing a digital asset such as an identity, certificate or message that are cryptographically signed.
2. Field:
   Single data item of a certain type that can be validated on a Document.
3. Portfolio:
   A collection of documents that belong together, usually issued or owned by an Entity.

4. Facade:
   The front of a Node that always must validate documents according to policies in order to accept or interact with them. Each Facade has an owning Portfolio.
5. Foreign Facade:
   Technical term for a Facade that is foreign in relationship to a certain said Portfolio.
6. Native Facade:
   Technical term for a Facade that is native, usually in relationship to its owning Portfolio which also contains private information.
7. Internal Document
   A Document that privately belongs to a Portfolio and is internal to its Native Facade. Internal Documents should never be exported from the Native Facade and only be shared between Nodes within the same Domain.
8. Node
   An Angelos installation on a device that is either a Client or Server. Each Node has a Facade with owning Portfolio. Every Node is a member of a Domain. The Node is represented in the owning Portfolio by a Node Document and is an Internal Document.
9. Domain
   The Domain represents the belonging relationship of Nodes to an owning Portfolio. The Domain is represented in the owning Portfolio by a Domain Document and is an Internal Document.