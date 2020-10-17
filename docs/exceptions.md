# Exceptions in Angelos source code

In order to find and resolve bugs in the source code we are required to follow certain coding conduct when developing software.

1. It is forbidden to catch all exceptions by using, catch-everything kind of try/catch blocks.
2. Only use `RuntimeWarning` when exceptions are meant to be intercepted.
3. Only use `RuntimeError` exceptions when something goes wrong that should be fixed, i.e. a bug in the software.
4. Only catch all exceptions at the beginning of a main function or thread that may not display tracebacks when error happens.

## When to use exceptions

```python
try:
	# Some code and function calls
except RuntimeError as e:
	logging.error(e)
```

**Never do like this!**

```python
try:
	# Some code and function calls
except RuntimeError
	pass
```

**Never do like this!**

```python
try:
	if something:
		raise RuntimeWarning("That went wrong.")
except RuntimeWarning:
	pass
finally:
	clean_up()
```

**This is not ok.**

```python
try:
	if something:
		raise RuntimeWarning("That went wrong.")
except RuntimeWarning:
	do_different()
```

**This is OK.**

```python
try:
	if something:
		raise RuntimeWarning("That went wrong,")
except RuntimeWarning:
	raise RuntimeWarning("Explanation what happened.")
```

**This is preferable.**

```python
try:
	if something:
		rasie RuntimeWarning("That went wrong.")
except RuntimeWarning:
	pass
else:
	raise RuntimeWarning("Explanation what happened.")
```

**This is preferable.**

## This is how to raise a RuntimeError

```python
import logging
import foo, bar, baz

class SpecialError(RuntimeError):
	"""Module specific RuntimeError implementation."""
	AINT_WORKING = ("Something is not working.", 100)
	SOMETHING_WRONG = ("Something is wrong.", 101)
	SUSPICIOUS_ERROR = ("Suspicious error happened.", 102)
	
def do_stuff():
	if not foo.status():
		raise SpecialError(*SpecialError.SOMETHING_WRONG, {"meta": foo.info})
		
if __name__ == "__main__":
	try:
		do_stuff()
	exception Exception as e:
		logging.critical(e, exc_info=True)
```

This is how to use `RuntimeError` based exceptions.

## This is how to raise a RuntimeWarning

```python
import foo, bar, baz

class ThisHappened(RuntimeWarning):
	pass
	
class ThatHappened(RuntimeWarning):
	pass
	
def do_this(input):
	if what_happened == input:
		raise ThisHappened()
	
	foo.is_true()
	
def do_that(data):
	if data:
		raise ThatHappened()
		
	try:
		do_this(that):
	except ThisHappened:
		bar.something_else()

```

This is how to do it.