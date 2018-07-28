from setuptools import setup, find_packages
import sys, os

version = '0.0'

setup(name='app',
      version=version,
      description="Core app of angelos",
      long_description="""\
""",
      classifiers=[], # Get strings from http://pypi.python.org/pypi?%3Aaction=list_classifiers
      keywords='',
      author='Kristoffer Paulsson',
      author_email='kristoffer.paulsson@talenten.se',
      url='',
      license='MIT',
      packages=find_packages(exclude=['ez_setup', 'examples', 'tests']),
      include_package_data=True,
      zip_safe=False,
      install_requires=[
          # -*- Extra requirements: -*-
      ],
      entry_points="""
      # -*- Entry points: -*-
      """,
      )
