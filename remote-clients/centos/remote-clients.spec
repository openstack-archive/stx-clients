Summary: Remote-Clients
Name: remote-clients
Version: 2.0.6
Release: %{tis_patch_ver}%{?_tis_dist}
License: Apache-2.0
Group: devel
Packager: Wind River <info@windriver.com>
URL: unknown


Source0: %{name}-%{version}.tar.gz

BuildRequires: python-cinderclient-sdk
BuildRequires: python-gnocchiclient-sdk
BuildRequires: python-glanceclient-sdk
BuildRequires: python-heatclient-sdk
BuildRequires: python-keystoneclient-sdk
BuildRequires: python-neutronclient-sdk
BuildRequires: python-novaclient-sdk
BuildRequires: python-openstackclient-sdk
BuildRequires: python-openstacksdk-sdk
BuildRequires: cgts-client-sdk
BuildRequires: python-muranoclient-sdk
BuildRequires: distributedcloud-client-sdk
BuildRequires: python-fmclient-sdk

%define cgcs_sdk_deploy_dir /opt/deploy/cgcs_sdk
%define remote_client_dir /usr/share/remote-clients
%global debug_package %{nil}

%description
Remote-Client files

%prep
%setup

%build
make NAME=%{name} \
     VERSION=%{version} \
     REMOTE_CLIENT_DIR=%{remote_client_dir}

# Install for guest-client package
%install
make install NAME=%{name} \
     VERSION=%{version} \
     SDK_DEPLOY_DIR=%{buildroot}%{cgcs_sdk_deploy_dir}

%files
%{cgcs_sdk_deploy_dir}/wrs-%{name}-%{version}.tgz
