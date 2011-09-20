# The purpose of this file is to make equality use method calls in as
# many Ruby implementations as possible. If method calls are used,
# then equality operations using dataflow variaables becomes seemless
# I realize overriding core classes is a pretty nasty hack, but if you
# have a better idea that also passes the equality_specs then I'm all
# ears. Please run the rubyspec before committing changes to this file.

class Object
  alias original_equality ==

  def ==(other)
    object_id == other.object_id
  end
end

class Symbol
  alias original_equality ==

  def ==(other)
    object_id == other.object_id
  end
end

class Regexp
  alias original_equality ==

  if /lol/.respond_to?(:encoding)
    def ==(other)
      other.is_a?(Regexp) &&
      casefold? == other.casefold? &&
      encoding == other.encoding &&
      options == other.options &&
      source == other.source
    end
  else
    def ==(other)
      other.is_a?(Regexp) &&
      casefold? == other.casefold? &&
      kcode == other.kcode &&
      options == other.options &&
      source == other.source
    end
  end
end
