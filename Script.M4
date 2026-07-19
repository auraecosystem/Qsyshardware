dnl This is a comment line. 'dnl' means Discard to New Line.
dnl Defining a basic text macro substitution string
define(`AUTHOR_NAME', `seriki yakub')

dnl Defining a macro function that accepts an argument ($1)
define(`GREET_USER', `Welcome back, $1!')

dnl Operational code text
Project Maintainer: AUTHOR_NAME
Status: GREET_USER(AUTHOR_NAME)
