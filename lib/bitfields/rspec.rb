RSpec::Matchers.define :have_a_bitfield do |field|
  match do |klass|
    klass.respond_to?(field) &&
    klass.respond_to?(field) &&
    klass.respond_to?("#{field}?") &&
    klass.respond_to?("#{field}=")
  end

  failure_message do |klass|
    "expected #{expected.join} to be a bitfield property defined on #{klass}"
  end

  failure_message_when_negated do |klass|
    "expected #{expected.join} to NOT be a bitfield property defined on #{klass}"
  end

  description do
    "be a bitfield on #{expected}"
  end
end
