# cis_module_gen

**WARNING**: This is very much a WIP

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with cis_module_gen](#setup)
    * [Setup requirements](#setup-requirements)
    * [Beginning with cis_module_gen](#beginning-with-cis_module_gen)
3. [Usage - Configuration options and additional functionality](#usage)

## Description

Briefly tell users why they might want to use your module. Explain what your module does and what kind of problems users can solve with it.

This should be a fairly short description helps the user decide if your module is what they want.

## Setup

### Setup Requirements

1. Install the [PDK](https://puppet.com/docs/pdk/1.x/pdk_install.html)
2. Clone this repo locally
3. Download the desired CIS benchmark .xls file. For example `CIS_Microsoft_Windows_Server_2016_RTM_Release_1607_Benchmark_v1.1.0.xls`
4. Change directory into the cloned module
5. `pdk bundle install --with development`

### Beginning with cis_module_gen

`pdk bundle exec ruby lib/generate.rb`

The very basic steps needed for a user to get the module up and running. This can include setup steps, if necessary, or it can be an example of the most basic use of the module.

## Usage

Run the following from within the cloned repo:
`pdk bundle exec ruby lib/generate.rb -s ~/Downloads/CIS_Microsoft_Windows_Server_2016_RTM_Release_1607_Benchmark_v1.1.0.xls -v server2016 -n windows`

This will parse the benchmark excel `~/Downloads/CIS_Microsoft_Windows_Server_2016_RTM_Release_1607_Benchmark_v1.1.0.xls`
to create the following dir structure:
```
manifests/
└── server2016
    ├── level_1
    │   ├── domain_controller
    │   │   ├── account_policies.pp
    │   │   ├── administrative_templates_computer.pp
    │   │   ├── administrative_templates_user.pp
    │   │   ├── advanced_audit_policy_configuration.pp
    │   │   ├── local_policies.pp
    │   │   └── windows_firewall_with_advanced_security.pp
    │   └── member_server
    │       ├── account_policies.pp
    │       ├── administrative_templates_computer.pp
    │       ├── administrative_templates_user.pp
    │       ├── advanced_audit_policy_configuration.pp
    │       ├── local_policies.pp
    │       └── windows_firewall_with_advanced_security.pp
    ├── level_2
    │   ├── domain_controller
    │   │   ├── administrative_templates_computer.pp
    │   │   ├── administrative_templates_user.pp
    │   │   └── local_policies.pp
    │   └── member_server
    │       ├── administrative_templates_computer.pp
    │       ├── administrative_templates_user.pp
    │       └── local_policies.pp
    └── next_generation_windows_securit
        └── administrative_templates_computer.pp
```
## Limitations

In the Limitations section, list any incompatibilities, known issues, or other warnings.
