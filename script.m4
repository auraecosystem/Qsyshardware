dnl Initialize Autoconf with project name, version, and maintainer email
AC_INIT([M4_Developer_Suite],, [dev-support@example.com])

dnl Safety verification check: Make sure a reliable source file exists in the directory
AC_CONFIG_SRCDIR([main.c])

dnl Configure build system to output a clean 'config.h' header file
AC_CONFIG_HEADERS([config.h])

dnl Force checking for a valid local native C compiler (gcc, clang, etc.)
AC_PROG_CC

dnl Custom M4 Macro: Verify if the system architecture running the build is ARM64
AC_MSG_CHECKING([if building on arm64 architecture])
AS_IF([test "$(uname -m)" = "arm64"], [
    AC_MSG_RESULT([yes])
    AC_DEFINE([USING_ARM64], [1], [Defined if building natively on ARM64 silicon])
], [
    AC_MSG_RESULT([no])
])

dnl Output final project configuration artifacts (like Makefiles)
AC_CONFIG_FILES([Makefile])
AC_OUTPUT
