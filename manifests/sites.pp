# Set systemwide path so that "exec" resource knows which paths are existing
Exec {
  path => $facts['path'],
}

node default {
  lookup('server::role', { merge => unique }).include
}
