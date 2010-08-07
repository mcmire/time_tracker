# Quick little library to produce an ASCII table from an array of arrays.
# Here's a runthrough:
#
#   columnator = Columnator.new
#   columnator.headers = ["This", "And", "That"]
#   columnator << ["some", "like", "it"]
#   columnator << ["hot", "and", "some"]
#   columnator << ["like", "it", "colllllllld"]
#   puts columnator.columnate
#
# That will output:
#
#   | This | And  | That        |
#   |------|------|-------------|
#   | some | like | it          |
#   | hot  | and  | some        |
#   | like | it   | colllllllld |
#
# Lookatthat, the columns are all the same width! Isn't that neat?!?
#
class Columnator
  ALIGNMENT_METHODS = {
    :left => :ljust,
    :right => :rjust
  }
  
  def self.columnate(*args)
    new(*args).columnate
  end
  
  attr_accessor :rows, :headers, :alignments, :out
  
  def initialize(rows_or_options=[], options={})
    if Hash === rows_or_options
      @options = rows_or_options
    else
      @rows = rows_or_options
      @options = options
    end
    @alignments = @options.delete(:alignments) || []
    @headers = @options.delete(:headers)
    @out = @options.delete(:write_to) == :array ? [] : ""
  end
  
  def <<(row)
    @rows << row
  end
  
  def columnate
    # find max length of each column
    for row in table
      find_max_length!(row)
    end
    # now generate the ASCII table
    if @headers
      format_column!(@headers)
      if @options[:header_divider]
        divider = column_widths.map {|w| @options[:header_divider] * w }
        format_column!(divider)
      end
    end
    for row in @rows
      format_column!(row)
    end
    @out
  end
  
private
  def column_widths
    @column_widths ||= ([0] * size)
  end
  
  def table
    @table ||= (@headers ? ([@headers] + @rows) : @rows)
  end
  
  def size
    table[0].size
  end
  
  def find_max_length!(row)
    row.each_with_index do |col, i|
      len = col.to_s.length
      column_widths[i] = len if len > column_widths[i]
    end
  end
  
  def format_column!(row)
    row2 = []
    row.each_with_index do |col, i|
      alignment = ALIGNMENT_METHODS[@alignments[i] || :left]
      row2 << (alignment ? col.to_s.send(alignment, column_widths[i], " ") : col.to_s)
    end
    div = @options[:column_divider]
    line = ""
    line += div + " " if div
    line += row2.join(div ? (" " + div + " ") : "")
    line += " " + div if div
    line += "\n"
    @out << line
  end
end