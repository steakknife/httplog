require 'rainbow'

module Kernel
  # Colorify('abcd').italic_light_blue_bg_gray
  def Colorify(s)
    Colorify.new(s)
  end
end

class Colorify
  def initialize(s)
    @s = Rainbow(s)
  end

  def respond_to_missing?(m, include_all)
    m = m.to_s
    if m =~ /_/
      m.split('_').all? { |c| @s.respond_to_missing? c }
    else
      @s.respond_to_missing? m
    end
  end

  def method_missing(m, *args)
    if (compound = m.to_s) =~  /_/
      bg = false
      compound.split('_').each do |c|
        if bg
          bg = false
          apply_bg(c)
        else
          if c == 'bg'
            bg = true
          else
            apply_fg(c)
          end
        end
      end
      @s
    else
      apply_fg(m)
    end
  end

private

  def apply_bg(c)
    c = sanitize(c)
    @s = @s.bg(c)
  end

  def apply_fg(c)
    c = sanitize(c)
    c = :bright if c == :light
    @s = @s.public_send(c)
  end

  def sanitize(c)
    if (hex = c.to_s) =~ /\A[[:xdigit:]]{6}\z/
      "##{hex.upcase}"
    else
      c.to_sym
    end
  end
end
