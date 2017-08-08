%global __os_install_post %{nil}

Name:		rdba-audit
Version:	0.0
Release:	0
Summary:	Remote DBA audit generator

Group:		Applications/Databases
Vendor:     Aleksandr Kuzminsky
License:	GPL
URL:		http://www.percona.com/products/mysql-remote-dba
Source:	    %{name}-%{version}.tar.gz
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildArch:  noarch
BuildRequires: coreutils 
%description
Remote DBA audit generator is a set of scripts that help a DBA to produce 
performance audit of a server. It includes scripts that collect information
and generate the report. The result is a set of rst files.

%package collect
Summary:        Scripts to collect information for Remote DBA audit generator
Group:          Applications/Databases
Requires:       coreutils util-linux grep sed findutils which bash sysstat procps dmidecode mysql percona-toolkit mysql-server
%description collect
The package provides scripts to collect varios server metrics and configuration
for performance audit report

%package report
Summary:        Scripts to generate a performance audit template
Group:          Applications/Databases
Requires:       bash finger coreutils wget grep gawk sed gnuplot >= 4.2.0 percona-toolkit rst2pdf
%description report
The package provides scripts to generate a prferomance audit template from data collected by %{name}-collect

%prep
%setup -q


%build

echo "Build step is not needed"


%install
rm -rf %{buildroot}
# collect
install -d %{buildroot}/%{_bindir}/
install -m 755 collect.sh %{buildroot}/%{_bindir}/rdba-audit-collect
install -m 755 slow.sh %{buildroot}/%{_bindir}/rdba-audit-slow-log
# report
install -d %{buildroot}/%{_bindir}/
install -d %{buildroot}/%{_datadir}/rdba-audit
install -m 755 report.sh %{buildroot}/%{_bindir}/rdba-audit-report
install sub_routines.sh  %{buildroot}/%{_datadir}/rdba-audit
cp -R sub_routines %{buildroot}/%{_datadir}/rdba-audit

%clean
rm -rf %{buildroot}

%files collect
%defattr(755, root, root, 755>)
%{_bindir}/rdba-audit-collect
%{_bindir}/rdba-audit-slow-log

%files report
%defattr(755, root, root, 755>)
%{_datadir}/rdba-audit
%{_datadir}/rdba-audit/sub_routines
%{_bindir}/rdba-audit-report


%changelog
* Sat Nov 02 2013 Aleksandr Kuzminsky <aleksandr.kuzminsky@percona.com> - 0.0
- Initial package.

