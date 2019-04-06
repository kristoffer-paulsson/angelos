import datetime


class Glue:
    @staticmethod
    def meta_save(document):
        try:
            owner = document.owner
        except AttributeError:
            owner = document.issuer

        try:
            updated = datetime.datetime.combine(
                document.updated, datetime.datetime.min.time())
        except (AttributeError, TypeError):
            updated = None

        created = datetime.datetime.combine(
            document.created, datetime.datetime.min.time())

        return created, updated, owner
