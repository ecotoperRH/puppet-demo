consul {
  address = "localhost:8500"

  retry {
    enabled  = true
    attempts = 15
    backoff  = "250ms"
  }
}
