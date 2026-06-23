# Délègue au Makefile générique d'openFrameworks.
# Suppose que le projet est cloné dans <OF_ROOT>/apps/myApps/oscope-of/.

ifndef PROJECT_ROOT
    PROJECT_ROOT := $(realpath ./)
endif

include $(PROJECT_ROOT)/config.make

ifndef OF_ROOT
    OF_ROOT = ../../..
endif

include $(OF_ROOT)/libs/openFrameworksCompiled/project/makefileCommon/compile.project.mk
