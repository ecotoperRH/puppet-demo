# Class: profiles::base
#
# Set up base requirement for the entire system 
#
class profiles::base {
  include profiles::base::facts
  include profiles::base::packages
  include profiles::base::structure
}
