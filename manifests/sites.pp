node default {
  lookup('server::role', { merge => unique }).include
}
