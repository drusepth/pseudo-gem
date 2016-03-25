IMPLICIT_CONVERSIONS = [:to_ary, :to_str, :to_hash, :to_io]

class PseudoCodeGenerator

  attr_accessor :method_name, :args, :block

  attr_accessor :google_results_thread, :page_results_threads

  # Allow google'd snippets to look for code replacements for their missing methods?
  CASCADE_SNIPPETS = false

  #todo implement depth limit when cascading snippets is enabled
  CASCADE_MAXIMUM_DEPTH = 3

  def initialize method_name, args, block
    @method_name = method_name
    @args        = args
    @block       = block
  end

  def find_code!
    new_code = google("ruby #{method_name} site:stackoverflow.com")
                 .map    { |url|     fetch_code_from_page url }
                 .detect { |snippet| valid_code? snippet }
  end

  private

  def google query
    # google for stackoverflow questions similar to method name
    result_queue = []
    @google_results = Thread.new do
      Google::Search::Web.new(query: query).each do |result|
        result_queue << result.uri
      end
    end

    debug "Found #{result_queue.count} google search results"

    # todo wait for thread to finish and/or stream back through accumulator?
    result_queue
  end

  def fetch_code_from_page url
    active_threads = []
    code_snippets = Queue.new

    loop do
      # wait for another google result if the current queue is empty
      #todo only wait for 1 more result, not all of them
      @google_results_thread.join if result_queue.empty?

      break if result_queue.empty?

      uri = result_queue.pop 0
      active_threads << Thread.new do
        html = Nokogiri::HTML(open url)

        code_snippets << html.css('pre.lang-rb').map(&:text)
        code_snippets.flatten!
      end
    end

    code_snippets
  end

  def valid_code? code
    disable_method_missing! if private_methods.include?(:method_missing) && !CASCADE_SNIPPETS
    
    success = true
    retval = eval code
  rescue
    success = false
    retval = nil
  ensure
    enable_method_missing! if !private_methods.include?(:method_missing) && !CASCADE_SNIPPETS

    [success, retval]
  end

  def disable_method_missing!
    @method_missing_snapshot = method(:method_missing)

    # Wrap method_missing in a dummy method to prevent triggering
    #todo probably not thread safe -- make it so
    send(:define_method, :method_missing, ->(_){ })
  end

  def debug message
    puts message
  end
end

def method_missing method_name, *args, &block
  # filter out ruby's implicit conversion methods that trigger method_missing
  return if IMPLICIT_CONVERSIONS.include? method_name

  puts "Tried to call #{method_name} but it doesn't exist."
  puts "args: #{args.inspect}"
  puts "block: #{block.inspect}"

  generator = PseudoCodeGenerator method_name, args, block
  generator.find_code!

end
