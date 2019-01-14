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

%description
Remote-Client files

%prep
%setup
mv %{name} wrs-%{name}-%{version}
find %{remote_client_dir} -name "*.tgz" -exec cp '{}' wrs-%{name}-%{version}/ \;
sed -i 's/xxxVERSIONxxx/%{version}/g' wrs-%{name}-%{version}/README
tar czf wrs-%{name}-%{version}.tgz wrs-%{name}-%{version}

# Install for guest-client package
%install
install -D -m 644 wrs-%{name}-%{version}.tgz %{buildroot}%{cgcs_sdk_deploy_dir}/wrs-%{name}-%{version}.tgz

%files
%{cgcs_sdk_deploy_dir}/wrs-%{name}-%{version}.tgz

