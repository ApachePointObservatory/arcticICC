https://www.apo.nmsu.edu/Telescopes/TCC/OperatorsManual.html#UpdatingSoftware


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

Then to install the software completely:

Managing and Updating Software
Individual software packages are installed and managed using git and eups (scons commands use eups under the hood). Type "lsst" at the command line to setup the eups environment. Note it is expected that all packages have been initially eups declared (see Installing Software) by the time you get here! Also note that git and eups are separate systems, so it is up to the human typing to keep versions/tags coherent between the two.

Software updating procedure
1) When code is ready for a new tag (beta or otherwise) use git:

update the python __version__.py file
update the version history html file in the package's doc directory
git commit with a commit message including the tag number
"git push"
"git tag versionNumber"
"git push --tags"
2) Update code on ARCTIC machine.

Pull updates from repo: git pull or svn up
If the recent updates are "beta" updates, do not install via eups/scons. Use setup arcticICC -t test (this sets up the current state of git/svn products) for testing prior to installation. After successful testing, git tag a non-beta version and push again.
Install a new eups-managed package version and make it current:
If scons is available :
setup package and run unittests. From within the package directory: "setup -r ." --> "scons --clean" followed by "scons".
"scons install declare version=packageVersion current"
Note packageVersion should match the git tag, __version__.py, etc. It's up to the typest to keep these straight!
If scons tools are not available (eg, RO, actorkeys):
Copy the code to the installed location (choose the same location scons does). For svn packages, svn export is a good idea (to freeze the code)
"eups declare -r pathToInstalledLocation packageName packageVersion current".
Again packageVersion should match that of git.
For opscore and actorkeys, treat svn revision numbers like tags
