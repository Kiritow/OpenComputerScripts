# Grab Documentation

## Grab - Official OpenComputerScripts Installer

### Usage

    grab [<options>] <command> ...

### Options

*--cn*

    Use mirror site in China. By default grab will download from Github. This might be useful for only official packages.

*--help* 

    Display this help page.

*--version* 

    Display version and exit.

*--router=\<Router File>*

    Given a file which will be loaded and returns a route function like:
    function(RepoName: string, Branch: string ,FileAddress: string): string

*--proxy=\<Proxy File>*

    Given a file which will be loaded and returns a proxy function like:
    function(Url : string): boolean, string
    
*--skip-install*

    Library installers will not be executed.

*--refuse-license=\<License>*

    Set refused license. Separate multiple values with ','

*--accept-license=\<License> *

    Set accepted license. Separate multiple values with ','

### Command

**install \<Project> ...**

    Install projects. Dependency will be downloaded automatically.

**verify \<Provider> ...**

    Verify program provider info.

**add \<Provider> ...**

    Add program provider info.

**update**

    Update program info.

**clear**

    Clear program info.

**list**

    List available projects.

**search \<Name or Pattern>**

    Search projects by name

**show \<Project>**

    Show more info about project.

**download \<Filename> ...**

    Directly download files. (Not recommended)

### Notice

#### License

By downloading and using Grab, you are indicating your agreement to [MIT license](https://github.com/Kiritow/OpenComputerScripts/blob/master/LICENSE)

All scripts in official OpenComputerScript repository are under MIT license.

Before downloading any package under other licenses, Grab will ask you to agree with it.

This confirmation can be skipped by calling Grab with `--accept-license`.

Example:

    --accept-license=mit means MIT License is accepted. 
    --refuse-license=mit means MIT License is refused. 
    --accept-license means all licenses are accepted.
    --refuse-license means all licenses are refused. (Official packages are not affected.)

If a license is both accepted and refused, it will be refused.

#### Program Provider

A package is considered to be official only if it does not specified repo and proxy. Official packages usually only depend on official packages.

You can also install packages from unofficial program provider with Grab, but Grab will not check its security.

Notice that override of official packages is not allowed.

#### Router and Proxy

    route_func(RepoName: string, Branch: string ,FileAddress: string): string

A route function takes repo, branch and file address as arguments, and returns a resolved url.
It can be used to boost downloading by redirecting requests to mirror site.

As router functions can be used to redirect requests, Grab will give an warning if `--router` option presents.

    proxy_func(Url : string): boolean, string

A proxy function takes url as argument, and returns at least 2 values.

It can be used to handle different protocols or low-level network operations like downloading files via SOCKS5 proxy or in-game modem network.

The first returned value is true if content is downloaded successfully. Thus, the second value will be the downloaded content.

If the first value is false, the downloading is failed. The second value will then be the error message.

If proxy functions throw an error, Grab will try the default downloader.

As proxy functions can handle low-level network operations, Grab will give an warning if `--proxy` option presents.

## Explaination of programs list

An official programs list is maintained as [programs.info](programs.info). You can keep your local programs list up to date by running `grab update`.

You can add third party program providers to grab with `grab add <Provider>`. The provider argument can be the name of a local file or an url.

See [example programs list](programs.info.example) for more detailed information.