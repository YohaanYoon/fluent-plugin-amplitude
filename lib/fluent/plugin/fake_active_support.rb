# Some things we want from ActiveSupport
module FakeActiveSupport
  def simple_symbolize_keys(hsh)
    Hash[hsh.map do |k, v|
      begin
        [k.to_sym, v]
      rescue
        [k, v]
      end
    end]
  end

  def blank?(var)
    # rubocop:disable DoubleNegation
    var.respond_to?(:empty?) ? !!var.empty? : !var
    # rubocop:enable DoubleNegation
  end

  def present?(var)
    !blank?(var)
  end
end
