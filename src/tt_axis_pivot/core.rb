#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'


#-------------------------------------------------------------------------------

module TT::Plugins::AxisPivot


  ### MENU & TOOLBARS ### --------------------------------------------------

  unless file_loaded?( __FILE__ )
    parent_menu = ($tt_menu) ? $tt_menu : UI.menu('Tools')
    parent_menu.add_item('Pivot around Axis')  { self.pivot_tool }
  end


  ### MAIN SCRIPT ### ------------------------------------------------------

  def self.pivot_tool
    model = Sketchup.active_model
    sel = model.selection
    if sel.single_object? && sel[0].is_a?(Sketchup::ComponentInstance)
      model.tools.push_tool( Pivot.new( sel[0] ) )
    end
  end


  class Pivot
    APERTURE = 10

    def initialize(instance)
      @instance = instance
    end


    def activate
      @mouseover = nil
      @selected = nil
      @vector = nil
      @p = nil
      @mp = nil
      @lp = nil
    end


    def deactivate(view)
      view.invalidate
    end


    def onMouseMove(flags, x, y, view)
      pivot,xv,yv,zv = get_axis(view)
      t = @instance.transformation

      if @selected
        @mp = [x, y, 0]

        #angle = @p.distance(@mp).to_f.degrees / 3.0
        angle = ( @lp.y - @mp.y ) / 50.0
        tr = Geom::Transformation.rotation(pivot, @vector, angle)
        #@instance.transformation = @t * tr
        @instance.transform!( tr )
      else
        @mouseover = nil

        ph = view.pick_helper
        ph.do_pick(x,y)

        xaxis = [pivot, xv]
        yaxis = [pivot, yv]
        zaxis = [pivot, zv]

        if ph.pick_segment(xaxis, x, y)
          @mouseover = :xaxis
        elsif ph.pick_segment(yaxis, x, y)
          @mouseover = :yaxis
        elsif ph.pick_segment(zaxis, x, y)
          @mouseover = :zaxis
        end
      end

      @lp = [x, y, 0]

      view.invalidate
    end


    def onLButtonDown(flags, x, y, view)
      @selected = nil
      ph = view.pick_helper
      ph.do_pick(x,y)

      pivot,xv,yv,zv = get_axis(view)
      t = @instance.transformation

      xaxis = [pivot, xv]
      yaxis = [pivot, yv]
      zaxis = [pivot, zv]

      if ph.pick_segment(xaxis, x, y)
        @selected = :xaxis
        @vector = t.xaxis
      elsif ph.pick_segment(yaxis, x, y)
        @selected = :yaxis
        @vector = t.yaxis
      elsif ph.pick_segment(zaxis, x, y)
        @selected = :zaxis
        @vector = t.zaxis
      end

      if @selected
        Sketchup.active_model.start_operation('Pivot about Axis')
        @t = @instance.transformation.clone
        @p = [x, y, 0]
      end

      view.invalidate
    end


    def onLButtonUp(flags, x, y, view)
      Sketchup.active_model.commit_operation if @selected
      @selected = nil
      @mp = nil
      view.invalidate
    end


    def draw(view)
      if @selected && @mp
        p1 = @p.map { |n| n + 0.5 }
        p2 = @mp.map { |n| n + 0.5}

        view.line_width = 1
        view.drawing_color = [64,64,64]

        view.line_stipple = '-'
        view.draw2d(GL_LINES, p1, [p1.x, p2.y, 0])

        view.line_stipple = '.'
        view.draw2d(GL_LINES, [p1.x, p2.y, 0], p2)
      end

      # Axes info
      pivot,x,y,z = get_axis(view)

      # Vectors
      draw_vector(pivot, x, [255,0,0], view, @mouseover == :xaxis) # X
      draw_vector(pivot, y, [0,255,0], view, @mouseover == :yaxis) # Y
      draw_vector(pivot, z, [0,0,255], view, @mouseover == :zaxis) # Z

      # Points
      view.line_width = 2
      view.line_stipple = ''
      view.draw_points(pivot, 10, 4, [0,0,0]) # Pivot
      view.draw_points(x, 5, 1, [255,0,0]) # X
      view.draw_points(y, 5, 1, [0,255,0]) # Y
      view.draw_points(z, 5, 1, [0,0,255]) # Z
    end


    def draw_vector(pt1, pt2, color, view, selected = false)
      view.line_width = (selected) ? 4 : 2
      view.line_stipple = ''
      view.drawing_color = color
      p1 = view.screen_coords(pt1)
      p2 = view.screen_coords(pt2)
      view.draw2d(GL_LINES, p1, p2)
    end


    def get_axis(view)
      t = @instance.transformation
      pivot = t.origin
      size = view.pixels_to_model(80, pivot)
      x = pivot.offset(t.xaxis, size)
      y = pivot.offset(t.yaxis, size)
      z = pivot.offset(t.zaxis, size)
      [pivot, x, y, z]
    end


  end # class Pivot


  ### HELPER METHODS ### ---------------------------------------------------

  def self.start_operation(name)
    model = Sketchup.active_model
    if Sketchup.version.split('.')[0].to_i >= 7
      model.start_operation(name, true)
    else
      model.start_operation(name)
    end
  end

end # module

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------
