# frozen_string_literal: true

require "csv"

module AspaceDataTools
  module Create
    class Resources
      # @param input [String] path to CSV containing resource data
      # @param repo [Integer] database id of repo in which resources will be
      #   created
      # @param mode [:map, :map_and_create]
      def initialize(input:, repo: 2, mode: :post)
        @input = File.expand_path(input)
        @repo = repo.to_s
        @mode = mode
        check_for_file
        @report_path = @input.sub(/\.csv$/, "_report.csv")
        @json_path = @input.sub(/\.csv$/, ".json")
        @client = ADT.client
        @success = 0
        @failed = 0
      end

      def call
        mapped = map_csv_data
        if mode == :map
          generate_report(mapped)
          return
        end

        posted = post(mapped)
        generate_report(posted)
      end

      private

      attr_reader :input, :repo, :mode, :report_path, :json_path, :client,
        :csv_data

      def check_for_file
        return if File.file?(input)

        fail("❌ CSV not found: #{input}\n   Usage: ruby "\
             "create_resources_from_csv.rb /path/to/resources.csv "\
             "[default_repo_id]")
      end

      def map_csv_data
        @csv_data = CSV.read(input, headers: true)
        recs = csv_data.map { |row| row_to_json(row) }
        jrecs = recs.map { |rec| rec[:rec] }.compact
        File.open(json_path, "w") { |f| f << JSON.pretty_generate(jrecs) }
        puts "Mapped CSV data to ArchivesSpace records"
        puts "  - JSON output to #{json_path}"
        puts "  - #{err_ct(recs, :map_status)} mapping errors"
        recs
      end

      def post(data)
        results = data.map { |h| post_record(h) }
        puts "Posted records to ArchivesSpace"
        puts "  - #{err_ct(results, :post_status)} ingest errors"
        results
      end

      def post_record(h)
        return skipped_post(h) if h[:map_status] == :failure

        uri = "/repositories/#{h[:repo_id]}/resources"
        result = client.post(uri, h[:rec])
        return successful_post(h, result) if result.status_code == 200

        h.merge({
          post_status: :failure,
          post_message: result.parsed
        })
      end

      def skipped_post(h)
        h.merge({post_status: :skipped})
      end

      def successful_post(h, result)
        h.merge({
          uri: result.parsed["uri"],
          id: result.parsed["id"],
          post_status: :success
        })
      end

      def generate_report(data)
        data.first[:row].headers
        newhdrs = data.map(&:keys).flatten.uniq - %i[row rec]
        data.map do |h|
          r = h[:row]
          r << newhdrs.map { |hdr| [hdr, h[hdr]] }.to_h
        end
        CSV.open(
          report_path, "w",
          headers: csv_data.headers,
          write_headers: true
        ) do |csv|
          csv_data.each { |r| csv << r }
        end
        puts "Wrote CSV report to #{report_path}"
      end

      def err_ct(recs, key) = recs.count { |rec| rec[key] == :failure }

      def row_to_json(row)
        repo_id = present_str(row["repo_id"]) || repo
        unitid = present_str(row["unitid"])
        eadid = present_str(row["eadid"])
        title = present_str(row["title"])
        level = present_str(row["level"])
        otherlevel = present_str(row["otherlevel"])
        publish_flag = present_bool(row["publish"], false) # required in script
        processing_note = present_str(row["processing_note"])
        rules = present_str(row["rules"])           # ASpace Description Rules

        # Content languages/scripts are now repeatable via language,
        #   language_2, ...
        has_language = suffixes.any? do |suf|
          present_str(row["language#{suf}"])
        end

        # required (finding aid language)
        language_desc = present_str(row["language_desc"])
        # required (finding aid script)
        script_desc = present_str(row["script_desc"])

        # --- required top-level checks ---
        missing = []
        missing << "unitid" if unitid.nil?
        missing << "title" if title.nil?
        missing << "level" if level.nil?
        if row["publish"].nil? || row["publish"].to_s.strip.empty?
          missing << "publish"
        end
        missing << "language" unless has_language
        # script is NOT required at content level
        missing << "language_desc" if language_desc.nil?
        missing << "script_desc" if script_desc.nil?

        unless missing.empty?
          raise "Missing required field(s): #{missing.join(", ")}"
        end

        # Build repeatables
        dates = build_dates(row)
        extents = build_extents(row)
        notes = build_notes(row, publish_flag)
        lang_materials = build_lang_materials(row, publish_flag)

        raise "At least one date subrecord is required" if dates.empty?
        raise "At least one extent subrecord is required" if extents.empty?

        resource = {
          "jsonmodel_type" => "resource",
          "id_0" => unitid,
          "ead_id" => eadid,
          "title" => title,
          "level" => level,
          "other_level" => otherlevel,
          "publish" => publish_flag,
          "processing_note" => processing_note,
          # Description Rules (optional)
          "finding_aid_description_rules" => rules,

          # Language & script of content (repeatable)
          "lang_materials" => lang_materials,

          # Language/Script of description (finding aid, NOT repeatable)
          "finding_aid_language" => language_desc,
          "finding_aid_script" => script_desc,

          # Repeatables
          "dates" => dates,
          "extents" => extents,
          "notes" => notes
        }

        # Build classifications array from URIs or IDs
        classification_refs = build_classification_refs(row, repo_id)
        unless classification_refs.empty?
          resource["classifications"] =
            classification_refs
        end

        {
          row: row,
          rec: compact_deep(resource),
          repo_id: repo_id,
          map_status: :success
        }
      rescue => err
        {
          row: row,
          repo_id: repo_id,
          map_status: :failure,
          map_message: err
        }
      end

      # ----------------- helpers -----------------
      def present_str(v)
        s = v.to_s
        s = s.encode("UTF-8", invalid: :replace, undef: :replace,
          replace: "").strip
        s.empty? ? nil : s
      end

      def present_bool(v, default = false)
        str = v.to_s.strip.downcase
        return default if str.empty?
        return true if %w[true t yes y 1].include?(str)
        return false if %w[false f no n 0].include?(str)
        default
      end

      def is_value?(cleaned)
        !cleaned.nil? && !is_empty?(cleaned)
      end

      def is_empty?(cleaned)
        cleaned.respond_to?(:empty?) && cleaned.empty?
      end

      def compact_deep(obj)
        case obj
        when Hash
          obj.each_with_object({}) do |(k, v), h|
            cleaned = compact_deep(v)
            h[k] = cleaned if is_value?(cleaned)
          end
        when Array
          obj.map { |v| compact_deep(v) }
            .reject { |v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
        else
          obj
        end
      end

      # suffixes for repeatable fields:
      # -> "", "_2", "_3", ... so language, language_2, language_3, ...
      def suffixes(max = 20)
        [""].concat((2..max).map { |i| "_#{i}" })
      end

      # Gather IDs/values from columns like base_col, base_col_2,
      #   base_col_3, ...
      def gather_ids(row, base_col, max_suffixes = 20)
        ids = []
        suffixes(max_suffixes).each do |suf|
          v = present_str(row["#{base_col}#{suf}"])
          ids << v if v
        end
        ids.uniq
      end

      # Build the classifications array
      # Priority:
      #   1. If classifications_uri* present, use those URIs directly as refs.
      #   2. Else, fall back to classification_id* and classification_term_id*.
      def build_classification_refs(row, repo_id)
        refs = []

        # 1) Use explicit URIs if present
        uri_strings = gather_ids(row, "classifications_uri")
        if uri_strings.any?
          uri_strings.each do |uri|
            # trust the CSV to hold a valid ref like
            #   "/repositories/2/classification_terms/5"
            refs << {"ref" => uri}
          end
          return refs
        end

        # 2) Fallback: build refs from IDs
        classification_ids = gather_ids(row, "classification_id")
        classification_term_ids = gather_ids(row, "classification_term_id")

        classification_ids.each do |cid|
          refs << {"ref" => "/repositories/#{repo_id}/classifications/#{cid}"}
        end

        classification_term_ids.each do |tid|
          refs << {
            "ref" => "/repositories/#{repo_id}/classification_terms/#{tid}"
          }
        end

        refs
      end

      # ----------------- builders -----------------

      # Dates (repeatable)
      def build_dates(row)
        dates = []
        suffixes.each do |suf|
          label = present_str(row["date_label#{suf}"]) || "creation"
          date_begin = present_str(row["date_begin#{suf}"])
          date_end = present_str(row["date_end#{suf}"])
          date_type = present_str(row["date_type#{suf}"]) ||
            (date_end ? "range" : "single")
          expression = present_str(row["date_expression#{suf}"])
          certainty = present_str(row["date_certainty#{suf}"])

          next if date_begin.nil? && expression.nil?

          date = {
            "jsonmodel_type" => "date",
            "label" => label,
            "date_type" => date_type
          }
          date["begin"] = date_begin if date_begin
          date["end"] = date_end if date_end
          date["expression"] = expression if expression
          date["certainty"] = certainty if certainty

          dates << date
        end
        dates
      end

      # Extents (repeatable)
      def build_extents(row)
        extents = []
        suffixes.each do |suf|
          portion = present_str(row["extent_portion#{suf}"]) || "whole"
          number = present_str(row["extent_number#{suf}"])
          extent_type = present_str(row["extent_type#{suf}"])
          container_summary = present_str(row["extent_container_summary#{suf}"])
          physical_details = present_str(row["extent_physical_details#{suf}"])
          dimensions = present_str(row["extent_dimensions#{suf}"])

          next if number.nil? || extent_type.nil?

          extents << compact_deep({
            "jsonmodel_type" => "extent",
            "portion" => portion,
            "number" => number,
            "extent_type" => extent_type,
            "container_summary" => container_summary,
            "physical_details" => physical_details,
            "dimensions" => dimensions
          })
        end
        extents
      end

      # --------------------------------------------------------------
      # Note constructors
      def singlepart_note(type:, content:, label:, publish:)
        {
          "jsonmodel_type" => "note_singlepart",
          "type" => type,
          "content" => [content],
          "label" => label,
          "publish" => publish
        }.delete_if { |_, v| v.nil? }
      end

      def multipart_note(type:, text:, label:, publish:)
        note = {
          "jsonmodel_type" => "note_multipart",
          "type" => type,
          "label" => label,
          "publish" => publish,
          "subnotes" => []
        }
        note_text = {
          "jsonmodel_type" => "note_text",
          "content" => text
        }
        note["subnotes"] << note_text
        note
      end

      def accessrestrict_note(text:, label:, publish:, begin_date:, end_date:,
        local_types:)
        note = multipart_note(type: "accessrestrict", text: text, label: label,
          publish: publish)
        rr = {}
        rr["begin"] = begin_date if begin_date
        rr["end"] = end_date if end_date
        if local_types && !local_types.empty?
          rr["local_access_restriction_type"] =
            Array(local_types).reject(&:nil?).map(&:to_s)
        end
        note["rights_restriction"] = rr unless rr.empty?
        note
      end

      # Notes (repeatable; includes singlepart, multipart, and accessrestrict)
      def build_notes(row, resource_publish)
        notes = []

        singlepart_types = %w[abstract physdesc physfacet physloc]

        multipart_types = %w[
          accruals
          acqinfo
          altformavail
          appraisal
          arrangement
          bioghist
          custodhist
          dimensions
          fileplan
          legalstatus
          odd
          originalsloc
          otherfindaid
          phystech
          prefercite
          processinfo
          relatedmaterial
          scopecontent
          separatedmaterial
          userestrict
        ]

        # Singlepart
        singlepart_types.each do |ntype|
          suffixes.each do |suf|
            body = present_str(row["#{ntype}#{suf}"])
            next unless body
            label = present_str(row["l_#{ntype}#{suf}"])
            pub = present_bool(row["p_#{ntype}#{suf}"], resource_publish)
            notes << singlepart_note(type: ntype, content: body, label: label,
              publish: pub)
          end
        end

        # Multipart (regular multipart notes, not accessrestrict)
        multipart_types.each do |ntype|
          suffixes.each do |suf|
            body = present_str(row["#{ntype}#{suf}"])
            next unless body
            label = present_str(row["l_#{ntype}#{suf}"])
            pub = present_bool(row["p_#{ntype}#{suf}"], resource_publish)
            notes << multipart_note(type: ntype, text: body, label: label,
              publish: pub)
          end
        end

        # Special: accessrestrict (multipart + rights_restriction), still in
        #   same notes array
        suffixes.each do |suf|
          body = present_str(row["accessrestrict#{suf}"])
          next unless body
          label = present_str(row["l_accessrestrict#{suf}"])
          pub = present_bool(row["p_accessrestrict#{suf}"], resource_publish)

          b = present_str(row["begin_accessrestrict#{suf}"]) ||
            present_str(row["begin_accessrestrict"])
          e = present_str(row["end_accessrestrict#{suf}"]) ||
            present_str(row["end_accessrestrict"])
          t = present_str(row["type_accessrestrict#{suf}"]) ||
            present_str(row["type_accessrestrict"])

          notes << accessrestrict_note(
            text: body, label: label, publish: pub,
            begin_date: b, end_date: e, local_types: t
          )
        end

        notes
      end

      # lang_materials (REPEATABLE language/script + optional langmaterial note)
      # Uses:
      #   language, script, langmaterial
      #   language_2, script_2, langmaterial_2
      #   language_3, script_3, langmaterial_3, ...
      def build_lang_materials(row, resource_publish)
        lang_materials = []

        suffixes.each do |suf|
          language = present_str(row["language#{suf}"])
          script = present_str(row["script#{suf}"])
          langnote = present_str(row["langmaterial#{suf}"])

          # Skip this slot if absolutely nothing is provided
          next if language.nil? && script.nil? && langnote.nil?

          lm = {
            "jsonmodel_type" => "lang_material",
            "language_and_script" => compact_deep({
              "jsonmodel_type" => "language_and_script",
              "language" => language,
              "script" => script
            })
          }

          if langnote
            lm["notes"] = [
              {
                "jsonmodel_type" => "note_langmaterial",
                "content" => [langnote],
                "publish" => resource_publish
              }
            ]
          end

          lang_materials << compact_deep(lm)
        end

        lang_materials
      end
    end
  end
end
