Summary: install-log-server
Name: install-log-server
Version: 1.1.2
Release: %{tis_patch_ver}%{?_tis_dist}
License: Apache-2.0
Group: devel
Packager: Wind River <info@windriver.com>
URL: unknown

Source0: %{name}-%{version}.tar.gz

%define cgcs_sdk_deploy_dir /opt/deploy/cgcs_sdk

%description
Titanium Cloud log server installation

%prep
%setup
mv %name wrs-%{name}-%{version}
tar czf wrs-%{name}-%{version}.tgz wrs-%{name}-%{version}

# Install for guest-client package
%install
install -D -m 644 wrs-%{name}-%{version}.tgz %{buildroot}%{cgcs_sdk_deploy_dir}/wrs-%{name}-%{version}.tgz

%files
%{cgcs_sdk_deploy_dir}/wrs-%{name}-%{version}.tgz

