#
# spec file for package os-autoinst-scripts-deps
#
# Copyright 2021 SUSE LLC
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           os-autoinst-scripts-deps
Version:        1
Release:        0
Summary:        Metapackage that contains the dependencies of openQA-related scripts
License:        MIT
Group:          Development/Tools/Other
BuildArch:      noarch
Url:            https://github.com/os-autoinst/scripts
# The following line is generated from dependencies.yaml
%define main_requires bash coreutils curl grep html-xml-utils jq openQA-client openssh-clients osc perl >= 5.010 perl(Data::Dumper) perl(FindBin) perl(Getopt::Long) perl(Mojo::File) perl(YAML::PP) sed sudo xmlstarlet
Requires:       %main_requires
Suggests:       salt
Suggests:       postgresql

%description
- auto-review - Automatically detect known issues in openQA jobs, label openQA jobs with ticket references and optionally retrigger
- openqa-investigate - Automatic investigation jobs with failure analysis in openQA

%prep

%build

%install

%check

%files

%changelog
