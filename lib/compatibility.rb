#!/usr/bin/env ruby
# encoding: utf-8
require 'spreadsheet'
require 'rubyXL'

module Spreadsheet
  class << self
    def open io_or_path, mode="rb+"
      if File.extname(io_or_path).downcase == '.xlsx'
        RubyXL::Parser.parse(io_or_path)
      else
        if io_or_path.respond_to? :seek
          Excel::Workbook.open(io_or_path)
        elsif block_given?
          File.open(io_or_path, mode) do |fh|
            yield open(fh)
          end
        else
          open File.open(io_or_path, mode)
        end
      end
    end
  end
  def Spreadsheet.date_cell(row, idx)
    if row.kind_of?(Spreadsheet::Excel::Row)
      row.at(idx) && row.date(idx)
    else
      data = row[idx]
      if data.is_a?(RubyXL::Cell)
        return data.value.respond_to?(:to_i) ? data.value.to_i : data.value
        return data.value if data.value.is_a?(DateTime)
        if data.value.class.to_s == 'DateTime'
          puts "data is_a RubyXL::Cell and value #{data.value.class} is_a? Date #{data.value.is_a?(Date)} DateTime #{data.value.is_a?(DateTime)}"
          return Date.new(1899,12,30)+data.to_date.value.to_i
        else
          return Date.new(1899,12,30)+data.value.to_i if data.is_a?(RubyXL::Cell)
        end
      end
    end
  end
end

module RubyXL
  class Worksheet
    def row(row_index)
      x = @sheet_data[row_index]
      def x.date(column_index)
        data = self[column_index]
        return data.value.respond_to?(:to_i) ? data.value.to_i : data.value
        # return Date.new(1899,12,30)+data.value.to_i if data.is_a?(RubyXL::Cell)
      end unless defined?(x.date)
      x
    end
  end
  class Workbook
    def worksheet(idx)
      self[idx]
    end
  end
  class Row < OOXMLObject
    def []=(ind, value)
      cells[ind] = value
    end
  end
  class Cell
    def to_i
      self.value.respond_to?(:to_i) ? self.value.to_i : self.value
    end
    def to_s
      self.value.to_s
    end
  end
end

