# Hierarchy
`Hierarchy` is an internal model of `Monarchy` and should not be used unless it is really necessary.

> hmm... sounds like `private`

## Methods
** We do not recommend to use it but if yo have to: **
We are using [Closure Tree][e5c808aa] behind `Hierarchy` class. There is a bunch of methods and functions available behind the hood. Check their documentation.

  [e5c808aa]: https://github.com/mceachen/closure_tree "Closure Tree"

## Scopes:

### .accessible_for
You can select all hierarchies accessible for specific user by using a scope: `accessible_for`, eg:
``` ruby
Monarchy.hierarchy_class.accessible_for(current_user)   # returns [hierarchy1, hierarchy2, hierarchy5]
```

### .in(resource, true)
You can select all hierarchies scoped into another by using scope: `in`:

- If the second argument is `true` (`true` is by default):
``` ruby
Monarchy.hierarchy_class.in(project.hierarchy) # returns [hierarchy1, hierarchy2, hierarchy5]
```
It will returns for you all `hierarchies` which parent is `project.hierarchy` or one of his children.

- If the second argument is `false`:
``` ruby
Monarchy.hierarchy_class.in(project.hierarchy, false) # returns [hierarchy1, hierarchy2]
```
It will returns for you all `hierarchies` which parent is `project.hierarchy`


## Relations

### #members
Return all members explicitly granted to the hierarchy.

### #users
Returns all users which have been granted explicitly to the hierarchy.

### #resource
Returns a resource model of the hierarchy.