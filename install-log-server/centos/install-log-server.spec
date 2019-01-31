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
%global debug_package %{nil}

%description
Titanium Cloud log server installation

%prep
%setup

%build
make NAME=%{name} VERSION=%{version}

# Install for guest-client package
%install
make install NAME=%{name} VERSION=%{version} SDK_DEPLOY_DIR=%{buildroot}%{cgcs_sdk_deploy_dir}

%files
%{cgcs_sdk_deploy_dir}/wrs-%{name}-%{version}.tgz
