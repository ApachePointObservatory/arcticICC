Instrument control code for the ARCTIC imager at Apache Point Observatory

See doc/html/index.html for documentation.

Process to load and test an actor:

Loading test actor


arctic-icc

type:
$su arctic
$ (in arctic home) source .bash_profile
$ lsst
$ eups list
$ eups list arcticICC -v
$ ps aux | grep python   see where it is running from
$ setup arcticICC  #setups the current arctic that is 'installed'
$ eups list
$ arcticICC status
$ arcticICC stop
$ arcticICC status  (not running)
$ git checkout branchname
$ setup -r . (sets up the branch relative)
$ eups list arcticICC -v

arcticICC start


