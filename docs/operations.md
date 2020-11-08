# Operations on Portfolios

The Portfolio with its Documents may be subject to a bunch of operations depending on use.

Categories of operations to be performed.

- Create: a new document, add to portfolio
- Update: an existing document, added to portfolio
  - Expiry date
  - Change values
- Accept: an updated document, add to portfolio
- AcceptRenewed: a renewed document , replace in portfolio
- AcceptUpdated: a modified document, replace in portfolio
- Remove: certain document, remove from portfolio
- Validate: certain document by itself
- Validate: certain document in relationship to a portfolio, don't add
- ValidatePrivate: certain document in relationship to a private portfolio, don't add

| Operation              | Portfolio | Private Portfolio | Document |
| ---------------------- | --------- | ----------------- | -------- |
| Person:Create          | ✗         | ✓                 | ✗        |
| Ministry:Create        | ✗         | ✓                 | ✗        |
| Church:Create          | ✗         | ✓                 | ✗        |
| Person:Update          | ✗         | ✓                 | ✗        |
| Ministry:Update        | ✗         | ✓                 | ✗        |
| Church:Update          | ✗         | ✓                 | ✗        |
| Keys:New               | ✗         | ✓                 | ✗        |
| Entity:Accept          | ✓         | ✗                 | ✗        |
| Entity:AcceptUpdated   | ✓         | ✗                 | ✗        |
| Keys:Accept            | ✓         | ✗                 | ✗        |
| Domain:Create          | ✗         | ✓                 | ✗        |
| Domain:Update          | ✗         | ✓                 | ✗        |
| Domain:ValidatePrivate | ✗         | ✓                 | ✗        |
| Node:Create            | ✗         | ✓                 | ✗        |
| Node:Update            | ✗         | ✓                 | ✗        |
| Node:ValidatePrivate   | ✗         | ✓                 | ✗        |
| Network:Create         | ✗         | ✓                 | ✗        |
| Network:Update         | ✗         | ✓                 | ✗        |
| Network:Accept         | ✓         | ✗                 | ✗        |
| Network:AcceptUpdated  | ✓         | ✗                 | ✗        |
| Verified:Create        | ✗         | ✓                 | ✗        |
| Trusted:Create         | ✗         | ✓                 | ✗        |
| Revoked:Create         | ✗         | ✓                 | ✗        |
| Verified:Accept        | ✓         | ✗                 | ✗        |
| Trusted:Accept         | ✓         | ✗                 | ✗        |
| Revoked:Accept         | ✓         | ✗                 | ✗        |
| Revoked:Remove         | ✓         | ✗                 | ✗        |
|                        |           |                   |          |

