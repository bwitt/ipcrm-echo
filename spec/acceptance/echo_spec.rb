require 'spec_helper_acceptance'

describe 'echo' do
  # Resources the last puppet apply's report marked as changed
  def changed_resources
    cmd = '/opt/puppetlabs/puppet/bin/ruby -rpuppet -e \'Puppet.initialize_settings; ' \
          'report = YAML.unsafe_load_file(Puppet[:lastrunreport]); ' \
          'puts report.resource_statuses.select { |_, s| s.changed }.keys\''
    on(default, cmd).stdout.split("\n")
  end

  # Applies the manifest, failing if puppet or its report records any change
  def apply_unchanged(manifest, **opts)
    result = apply_manifest(manifest, catch_changes: true, **opts)
    expect(changed_resources).to be_empty
    result
  end

  context 'with default parameters' do
    it 'logs the name with the resource path as a notice' do
      result = apply_unchanged("echo { 'TestMessage': }")
      expect(result.stdout).to match(%r{Notice: /Echo\[TestMessage\]/message: TestMessage})
    end
  end

  context 'with a message' do
    it 'logs the message instead of the name' do
      result = apply_unchanged("echo { 'TestMessage': message => 'Test message' }")
      expect(result.stdout).to match(%r{Notice: /Echo\[TestMessage\]/message: Test message})
      expect(result.stdout).not_to match(%r{message: TestMessage})
    end
  end

  context 'with withpath => false' do
    it 'logs the message without the resource path' do
      result = apply_unchanged("echo { 'TestMessage': message => 'Test message', withpath => false }")
      expect(result.stdout).to match(%r{Notice: Test message})
      expect(result.stdout).not_to match(%r{Echo\[TestMessage\]})
    end
  end

  context 'with loglevel' do
    {
      'info' => ['Info', :stdout],
      'warning' => ['Warning', :stderr],
      'err' => ['Error', :stderr],
      'crit' => ['Critical', :stderr],
    }.each do |loglevel, (label, stream)|
      it "logs at #{loglevel}" do
        result = apply_unchanged("echo { 'TestMessage': message => 'Test message', loglevel => '#{loglevel}' }")
        expect(result.public_send(stream)).to match(%r{#{label}: /Echo\[TestMessage\]/message: Test message})
        expect(result.stdout).not_to match(%r{Notice: /Echo\[TestMessage\]})
      end
    end

    it 'logs at debug only when debugging' do
      manifest = "echo { 'TestMessage': message => 'Test message', loglevel => 'debug' }"
      expect(apply_unchanged(manifest).stdout).not_to match(%r{Echo\[TestMessage\]})
      expect(apply_unchanged(manifest, debug: true).stdout).to match(%r{Debug: /Echo\[TestMessage\]/message: Test message})
    end
  end

  context 'with refreshonly => true' do
    it 'logs nothing when not notified' do
      result = apply_unchanged("echo { 'TestMessage': message => 'Test message', refreshonly => true }")
      expect(result.stdout).not_to match(%r{Test message})
    end

    it 'logs the message once when notified' do
      result = apply_manifest(<<-PUPPET, expect_changes: true)
        exec { 'trigger': command => '/bin/true', notify => Echo['TestMessage'] }
        echo { 'TestMessage': message => 'Test message', refreshonly => true }
      PUPPET
      expect(result.stdout.scan(%r{Echo\[TestMessage\]/message: Test message}).size).to eq(1)
    end
  end

  context 'with a schedule' do
    it 'logs the message inside the schedule' do
      result = apply_unchanged(<<-PUPPET)
        schedule { 'any_day': weekday => ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] }
        echo { 'TestMessage': message => 'Test message', schedule => 'any_day' }
      PUPPET
      expect(result.stdout).to match(%r{Notice: /Echo\[TestMessage\]/message: Test message})
    end

    it 'logs nothing outside the schedule' do
      result = apply_unchanged(<<-PUPPET)
        schedule { 'never': period => 'never' }
        echo { 'TestMessage': message => 'Test message', schedule => 'never' }
      PUPPET
      expect(result.stdout).not_to match(%r{Test message})
    end
  end
end
