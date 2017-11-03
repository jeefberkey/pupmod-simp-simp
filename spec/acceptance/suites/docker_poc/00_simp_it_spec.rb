require 'spec_helper_acceptance'

test_name 'simp it'

describe 'simp' do
  context 'set up each server to match the security settings of a real SIMP client' do
    hosts.each do |host|
      it 'should set the minimal hieradata required'
      it 'should include simp'
      it 'should run cleanly'
    end
  end
end
