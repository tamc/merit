module Merit
  # A LoadCurve is a container for LoadCurvevalues and is a timed series
  #
  # It will contain the 'global' methods for e.g. the total_profit of all the
  # load_curve_values
  class LoadCurve
    include Enumerable

    # Public: Creates a LoadCurve with the given +values+.
    #
    # values - The values for each point in the curve.
    #
    # Returns a LoadCurve.
    def initialize(values = [])
      @values = values
    end

    def get(point)
      @values[point] || 0.0
    end

    def set(point, value)
      @values[point] = value
    end

    def each
      length.times { |point| yield get(point) }
    end

    def length
      @values.length
    end

    def to_s
      "<#{self.class}: #{length} values>"
    end

    # Public: creates a new drawing in the terminal for this LoadCurve
    def draw!
      BarChart.new(to_a).draw
    end

    def draw
      BarChart.new(to_a).drawing
    end

    # Public: substract one load curve from the other
    def -(other)
      self.class.new(transpose_other_curve(other.to_a, :-))
    end

    # Public: substract one load curve from the other
    def +(other)
      self.class.new(transpose_other_curve(other.to_a, :+))
    end

    # Public: returns the sample variance
    def variance
      as_array = self.to_a

      mean = as_array.reduce(:+) / length.to_f
      sum  = as_array.reduce(0) { |accum, i| accum + (i - mean) ** 2 }

      sum / (length - 1).to_f
    end

    # Public: returns the standard deviation
    def sd
      Math.sqrt(variance)
    end

    # Public: outputs the current load_curve to a csv file
    def to_csv(file_name = 'output.csv')
      CSV.open(File.join(Merit.root, 'output', file_name), 'w') do |csv|
        each { |value| csv << [value] }
      end
    end

    #######
    private
    #######

    def transpose_other_curve(other, method)
      values = self.to_a

      v_length = values.length
      o_length = other.length

      if v_length > o_length
        other = other + ([0.0] * (v_length - o_length))
      elsif o_length > v_length
        values = values + ([0.0] * (o_length - v_length))
      end

      values.zip(other).map { |x| x.reduce(method) }
    end

  end # LoadCurve
end # Merit
