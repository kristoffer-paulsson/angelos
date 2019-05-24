"""Testing facade while refactoring."""
import sys
sys.path.append('../angelos')  # noqa

import tempfile

import libnacl

from support import random_person_entity_data
from angelos.const import Const
from angelos.facade.facade import PersonClientFacade
from angelos.archive.helper import Glue
from angelos.document.entities import Person, Keys
from angelos.document.domain import Domain, Node
from angelos.policy.entity import PersonGeneratePolicy


facade: Person
dir = tempfile.TemporaryDirectory()
home = dir.name
secret = libnacl.secret.SecretBox().sk
facade = Glue.run_async(PersonClientFacade.setup(
    home, secret, Const.A_ROLE_PRIMARY, random_person_entity_data(1)[0]))
# ext_policy = PersonGeneratePolicy()
# ext_policy.generate(**random_person_entity_data(1)[0])

print(
    facade.entity.export_str(),
    facade.keys.export_str(),
    facade.domain.export_str(),
    facade.node.export_str())

del facade
dir.cleanup()
