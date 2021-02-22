Infrastructure interfaces
=========================

## Terminology

__interface module:__ while technically a TF module, its purpose is to be a thin wrapper module representing
    an atomic piece of infrastructure that should be reused and instantiated by defining an *interface variable*
    and add an item to the list.

__interface variable:__ should always be of type `list` containing objects with the attribute `name` at least.

Module (name & folder) and variable show share the same name. 
