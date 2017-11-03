require 'spec_helper_acceptance'

test_name 'docker'

describe 'docker' do

  let(:manifest) { <<-EOS
      sysctl {'net.bridge.bridge-nf-call-iptables':  value => 1 }
      sysctl {'net.bridge.bridge-nf-call-ip6tables': value => 1 }

      class { 'docker':
        use_upstream_package_source => false, # use redhat docker
        service_overrides_template  => false, # use redhat docker
        selinux_enabled => 'true', # this is why we use redhat docker
        manage_epel     => false,
        package_name    => 'docker',
        log_driver      => 'journald',
        docker_group    => 'dockerroot',
        before          => [
          Sysctl['net.bridge.bridge-nf-call-iptables'],
          Sysctl['net.bridge.bridge-nf-call-ip6tables']
        ]
      }

      # DOESN'T WORK FOR NOW
      # include 'iptables'
      # iptables::listen::tcp_stateful { 'nginx':
      #   trusted_nets => ['ANY'],
      #   dports       => [80]
      # }
    EOS
  }

  context 'set up docker on hosts' do
    hosts.each do |host|
      it 'should apply with no errors' do
        apply_manifest_on(host, manifest, catch_failures: true, run_in_parallel: true)
        apply_manifest_on(host, manifest, catch_changes: true, run_in_parallel: true)
      end

      it 'should run hello-world via cli' do
        on(host, 'docker run hello-world', run_in_parallel: true)
      end

      it 'should run a built image' do
        run_manifest = manifest + <<-EOF
          docker::run { 'custom_nginx_#{host}':
            image => 'custom_nginx_#{host}',
            ports => ['80:80'],
          }
        EOF
        apply_manifest_on(host, run_manifest, catch_failures: true, run_in_parallel: true)
        apply_manifest_on(host, run_manifest, catch_changes: true, run_in_parallel: true)
        result = retry_on(host, 'curl localhost:80').stdout
        expect(result).to match(/Hello from Docker on SIMP/)
      end

      it 'should open up port 80' do
        on(host, 'iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT')
        on(host, 'iptables -A OUTPUT -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED -j ACCEPT')
      end
    end
  end

  context 'all hosts should be hosting the nginx page on port 80' do
    hosts.permutation(2).to_a.each do |first, second|
      it "#{first} can connect to #{second}" do
        result = retry_on(first, "curl #{second}:80").stdout
        expect(result).to match(/Hello from Docker on SIMP/)
        expect(result).to match(/I was built on #{second}/)
     end
    end
  end
end
