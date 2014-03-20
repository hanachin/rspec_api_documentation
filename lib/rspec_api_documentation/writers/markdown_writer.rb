require 'rspec_api_documentation/writers/formatter'

module RspecApiDocumentation
  module Writers
    class MarkdownWriter
      def self.write(index, configuration)
        index.examples.each do |rspec_example|
          example = MarkdownExample.new(rspec_example)
          FileUtils.mkdir_p(configuration.docs_dir.join(example.resource_name))
          File.open(configuration.docs_dir.join(example.resource_name, "index.md"), "a+") do |f|
            f.print example.description
            f.puts example.api_description + "\n\n" if example.api_description
            f.puts
            f.print example.parameters

            example.requests.each_with_index do |(request, response), i|
              f.puts "## Request:"
              f.puts
              f.puts example.request_description + "\n\n" if example.request_description
              f.puts request
              f.puts
              f.puts example.response_fields
              f.puts "## Response:"
              f.puts
              f.puts example.response_description + "\n\n" if example.response_description
              f.puts response

              if i + 1 < example.requests.count
                f.puts
              end
            end

            unless rspec_example == index.examples.last
              f.puts
              f.puts
            end
          end
        end
      end

      def self.format_hash(hash, separator="=")
        hash.sort_by { |k, v| k }.inject("") do |out, (k, v)|
          out << "  #{k}#{separator}#{v}\n"
        end
      end
    end

    class MarkdownExample
      attr_reader :example

      def initialize(example)
        @example = example
      end

      def resource_name
        example.resource_name.downcase.gsub(/\s+/, '_')
      end

      def description
        example.description + "\n" + "-" * example.description.length + "\n\n"
      end

      def api_description
        example.metadata[:api_description]
      end

      def parameter_headers
        hs = example.metadata[:parameters].map {|p|
          p.keys
        }.flatten.uniq
        default_hs = %i(name type required description)
        (default_hs & hs) + (hs - default_hs)
      end

      def max_width_for(header)
        len = [header.size, 3] +
          example.metadata[:parameters].map {|p|
            p[header].to_s.each_char.map{|c|
              c.ascii_only? ? 1 : 2
            }.inject(&:+)
          }
        len.compact.max
      end

      def max_width_for_response_fields(header)
        len = [header.size, 3] +
          example.metadata[:response_fields].map {|p|
            p[header].to_s.each_char.map{|c|
              c.ascii_only? ? 1 : 2
            }.inject(&:+)
          }
        len.compact.max
      end

      def format_s_for_header(header, s)
         non_ascii_count = s.to_s.each_char.reject {|c| c.ascii_only? }.count
         "%-#{max_width_for(header) - non_ascii_count}s" % s
       end

      def parameters
        return "" unless example.metadata[:parameters]
        "## Parameters:\n\n" +
        parameter_headers.map{|h| format_s_for_header(h, h) }.join(' | ') + "\n" +
        parameter_headers.map{|h| "-" * max_width_for(h)}.join(' | ') + "\n" + # sep
        example.metadata[:parameters].inject("") do |out, parameter|
          # out << "`#{parameter[:name]}` | #{parameter[:description]}\n"
          out << parameter_headers.map {|h| format_s_for_header(h, parameter[h]).split("\n").map(&:chomp).join("") }.join(' | ') + "\n"
        end + "\n"
      end

      def response_headers
        hs = example.metadata[:response_fields].map {|p|
          p.keys
        }.flatten.uniq
        default_hs = %i(name type description)
        (default_hs & hs) + (hs - default_hs)
      end

      def format_response_field(field, s)
         non_ascii_count = s.to_s.each_char.reject {|c| c.ascii_only? }.count
         "%-#{max_width_for_response_fields(field) - non_ascii_count}s" % s
      end

      def request_description
        example.metadata[:request_description]
      end

      def response_description
        example.metadata[:response_description]
      end

      def response_fields
        return "" unless example.metadata[:response_fields]
        "## ResponseFields:\n\n" +
        response_headers.map{|h| format_response_field(h, h) }.join(' | ') + "\n" +
        response_headers.map{|h| "-" * max_width_for_response_fields(h) }.join(' | ') + "\n" + # sep
        example.metadata[:response_fields].inject("") do |out, field|
          out << response_headers.map {|h| format_response_field(h, field[h]) }.join(' | ') + "\n"
        end + "\n"
      end

      def requests
        return [] unless example.metadata[:requests]
        example.metadata[:requests].map do |request|
          [format_request(request), format_response(request)]
        end
      end

      private
      def format_request(request)
        [
          [
            "    #{request[:request_method]} #{request[:request_path]}",
            format_hash(request[:request_headers], ": ")
          ],
          [
            format_string(request[:request_body]) || format_hash(request[:request_query_parameters])
          ]
        ].map { |x| x.compact.join("\n") }.reject(&:blank?).join("\n\n") + "\n"
      end

      def format_response(request)
        [
          [
            "    Status: #{request[:response_status]} #{request[:response_status_text]}",
            format_hash(request[:response_headers], ": ")
          ],
          [],
          [
            format_string(request[:response_body].blank? ? "" : (Formatter.to_json(JSON.parse(request[:response_body])) rescue request[:response_body]))
          ]
        ].map { |x| x.compact.join("\n") }.reject(&:blank?).join("\n\n") + "\n"
      end

      def format_string(string)
        return unless string
        string.split("\n").map { |line| "    #{line}" }.join("\n")
      end

      def format_hash(hash, separator="=")
        return unless hash
        hash.sort_by { |k, v| k }.map do |k, v|
          "    #{k}#{separator}#{v}"
        end.join("\n")
      end
    end
  end
end
