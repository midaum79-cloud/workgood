require 'holidays'

module HolidayHelper
  SUBSTITUTE_TARGETS = [
    "설날", "설날 연휴", "추석", "추석 연휴", "어린이날",
    "3·1절", "광복절", "개천절", "한글날", "석가탄신일", "크리스마스"
  ].freeze

  def self.get_holiday(date)
    holidays = Holidays.on(date, :kr)
    return holidays.first if holidays.any?

    return nil if date.saturday? || date.sunday?

    (1..4).each do |i|
      prev_date = date - i.days
      prev_holidays = Holidays.on(prev_date, :kr)
      
      if prev_holidays.any?
        name = prev_holidays.first[:name]
        
        if SUBSTITUTE_TARGETS.include?(name)
          if prev_date.saturday? || prev_date.sunday?
            between_days = (prev_date + 1.day...date).to_a
            all_off = between_days.all? do |d|
              d.saturday? || d.sunday? || Holidays.on(d, :kr).any?
            end
            
            if all_off
              return { name: "대체공휴일(#{name})", regions: [:kr] }
            end
          end
        end
      end
    end
    nil
  end
end

puts "2026-03-02 (Samiljeol sub): #{HolidayHelper.get_holiday(Date.new(2026,3,2))}"
puts "2026-05-25 (Buddha sub): #{HolidayHelper.get_holiday(Date.new(2026,5,25))}"
puts "2026-09-28 (Chuseok sub): #{HolidayHelper.get_holiday(Date.new(2026,9,28))}"
