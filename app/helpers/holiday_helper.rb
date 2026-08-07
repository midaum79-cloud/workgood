module HolidayHelper
  # 대체공휴일 적용 대상 목록 (대한민국)
  SUBSTITUTE_TARGETS = [
    "설날", "설날 연휴", "추석", "추석 연휴", "어린이날",
    "3·1절", "광복절", "개천절", "한글날", "석가탄신일", "크리스마스"
  ].freeze

  # 주어진 날짜의 공휴일 정보를 반환 (대체공휴일 포함)
  # 반환값: { name: "공휴일명", regions: [:kr] } 또는 nil
  def self.get_holiday(date)
    # 1. 원래 공휴일인지 확인
    holidays = Holidays.on(date, :kr)
    return holidays.first if holidays.any?

    # 2. 당일이 평일인지 확인. (주말이면 대체공휴일이 아님)
    return nil if date.saturday? || date.sunday?

    # 3. 대체공휴일 역추적 (최대 4일 전까지)
    # 연휴나 공휴일이 주말과 겹쳤고, 그 이후로 계속 쉬는 날(주말/공휴일)이었다면 오늘이 대체공휴일!
    (1..4).each do |i|
      prev_date = date - i.days
      prev_holidays = Holidays.on(prev_date, :kr)

      if prev_holidays.any?
        name = prev_holidays.first[:name]

        # 대체공휴일 적용 대상 공휴일인 경우
        if SUBSTITUTE_TARGETS.include?(name)
          # 해당 공휴일이 주말(토/일)과 겹쳤는지 확인
          # (설/추석 연휴 등은 주말이 아니더라도 다른 공휴일과 겹칠 수 있으나, 보통 주말과 겹침)
          if prev_date.saturday? || prev_date.sunday?
            # 해당 공휴일과 오늘 사이의 모든 날짜가 휴일(주말 또는 공휴일)이었는지 확인
            between_days = (prev_date + 1.day...date).to_a
            all_off = between_days.all? do |d|
              d.saturday? || d.sunday? || Holidays.on(d, :kr).any?
            end

            # 사이가 모두 휴일이었다면, 첫 번째 평일인 오늘이 대체공휴일
            if all_off
              return { name: "대체공휴일(#{name})", regions: [ :kr ] }
            end
          end
        end
      end
    end

    nil
  end
end
