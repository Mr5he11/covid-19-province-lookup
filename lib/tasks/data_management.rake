namespace :data_management do
  require 'open-uri'
  require 'csv'

  INIT_DATE_STRING = "24/02/2020"
  REPOSITORY_BASE_URL = "https://raw.githubusercontent.com/pcm-dpc/COVID-19/master/dati-province/dpc-covid19-ita-province-"

  desc "Import data from github directory"
  task :import_today_data, [:init_date_string] => :environment do |t, args|
    include DataManagement

    init_date_string = INIT_DATE_STRING
    if args[:init_date_string].present?
      init_date_string = args[:init_date_string]
    end

    import_all_data(init_date_string, REPOSITORY_BASE_URL)
  end

  module DataManagement

    def import_all_data(init_date_string, file_base_url)
      exit_loop = false
      today = DateTime.now
      date = DateTime.parse(init_date_string)

      data = Array.new
      nations = Array.new
      regions = Array.new
      provinces = Array.new

      while !exit_loop
        date_month = date.month > 9 ? "#{date.month}" : "0#{date.month}"
        date_day = date.day > 9 ? "#{date.day}" : "0#{date.day}"
        file_name_tail = "#{date.year}#{date_month}#{date_day}.csv"
        file_url = "#{file_base_url}#{file_name_tail}"

        puts "Importing data from #{date_day}/#{date_month}/#{date.year}..."
        begin
          URI.open(file_url) do |file|
            begin
              CSV.read(file, :headers => :first_row).each do |line|
                line_nation = get_nation(line)
                nations << line_nation if !nations.include?(line_nation)

                line_region = get_region(line)
                regions << line_region if !regions.include?(line_region)

                line_province = get_province(line)
                provinces << line_province if !provinces.include?(line_province)
                
                line_data = get_data(line)
                data << line_data
              end
            rescue CSV::MalformedCSVError => error
              puts "ERROR: malformed CSV - data import for #{date_day}/#{date_month}/#{date.year} failed."
            end
          end
          puts "Data acquired."
        rescue OpenURI::HTTPError => error
          puts "WARNING: data #{date_day}/#{date_month}/#{date.year} not currently available - skipping import."
        end

        date += 1.day
        exit_loop = (date.to_s.split("T").first == DateTime.tomorrow.to_s.split("T").first)
      end

      puts "Bulk inserting all collected data..."
      Nation.insert_all(nations)
      Region.insert_all(regions)
      Province.insert_all(provinces)
      EpidemicData.upsert_all(data, unique_by: %i[ date province_code ])
      puts "Bulk insertion done."
    end

    def get_data(line)
      {
        date: line['data'],
        total_cases: line['totale_casi'],
        notes: {
          'en' => line['note_en'],
          'it' => line['note_it']
        },
        province_code: line['codice_provincia']
      }
    end

    def get_province(line)
      {
        code: line['codice_provincia'],
        label: line['denominazione_provincia'],
        initials: line['sigla_provincia'],
        latitude: line['lat'].to_f,
        longitude: line['long'].to_f,
        region_code: line['codice_regione'],
        created_at: DateTime.now,
        updated_at: DateTime.now
      }
    end

    def get_region(line)
      {
        code: line['codice_regione'],
        label: line['denominazione_regione'],
        nation_code: line['stato'],
        created_at: DateTime.now,
        updated_at: DateTime.now
      }
    end

    def get_nation(line)
      {
        code: line['stato'],
        created_at: DateTime.now,
        updated_at: DateTime.now
      }
    end

  end
end