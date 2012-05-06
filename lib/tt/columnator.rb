#
# This is a little library to generate an ASCII table from an array of arrays.
# It's especially useful if you need to left-align or right-align
# certain columns in that table.
#
class Columnator
  ALIGNMENT_METHODS = {
    :left => :ljust,
    :right => :rjust
  }

  def self.columnate(*args)
    new(*args).columnate
  end

  attr_accessor :table, :alignments, :each_row, :generate_out, :out

  def initialize(table_or_options=[], options={})
    if Hash === table_or_options
      @options = table_or_options
    else
      @table = table_or_options
      @options = options
    end
    @alignments = @options.delete(:alignments) || []
    @out = []
    @each_row = lambda {|data, block| data.each(&block) }
    @generate_out = lambda {|data, block| data.map(&block) }
  end

  def <<(row)
    @table << row
  end

  def columnate
    calculate_size!
    initialize_column_widths!
    # find max length of each column
    @each_row.call(@table, lambda {|row| find_max_length!(row) })
    # now generate the ASCII table
    @out = @generate_out.call(@table, lambda {|row| format_column(row) })
    @out
  end

private
  def calculate_size!
    @each_row.call(@table, lambda {|row|
      @size = row.size
      next
    })
  end

  def initialize_column_widths!
    @column_widths = [0] * @size
  end

  def find_max_length!(row)
    row.each_with_index do |col, i|
      len = col.to_s.length
      @column_widths[i] = len if len > @column_widths[i]
    end
  end

  def format_column(row)
    row2 = []
    row.each_with_index do |col, i|
      alignment = ALIGNMENT_METHODS[@alignments[i] || :left]
      row2 << (alignment ? col.to_s.send(alignment, @column_widths[i], " ") : col.to_s)
    end
    row2.join("") + "\n"
  end
end
