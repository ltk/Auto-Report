class SimpleLinearRegression
  def initialize(xs, ys)
    @xs, @ys = xs, ys
    if @xs.length != @ys.length
      raise "Unbalanced data. xs need to be same length as ys"
    end
  end

  def y_intercept
    mean(@ys) - (slope * mean(@xs))
  end

  def slope
    x_mean = mean(@xs)
    y_mean = mean(@ys)

    numerator = (0...@xs.length).reduce(0) do |sum, i|
      sum + ((@xs[i] - x_mean) * (@ys[i] - y_mean))
    end

    denominator = @xs.reduce(0) do |sum, x|
      sum + ((x - x_mean) ** 2)
    end

    (numerator / denominator)
  end

  def mean(values)
    total = values.reduce(0) { |sum, x| x + sum }
    Float(total) / Float(values.length)
  end
end
class Visits
  extend Garb::Model

  metrics :visits, :pageviews
end
class VisitsByMobile
  extend Garb::Model

  metrics :visits, :pageviews
  dimensions :isMobile
end
class VisitsByDateAndMobile
  extend Garb::Model

  metrics :visits, :pageviews
  dimensions :isMobile, :date, :dayOfWeek
end
class VisitsByMedium
  extend Garb::Model

  metrics :visits, :pageviews
  dimensions :medium
end
class VisitsByDate
  extend Garb::Model

  metrics :visits, :pageviews
  dimensions :date, :dayOfWeek # 0 = Sunday, 6 = Monday
end
class StatsByDayAndTime
  extend Garb::Model

  metrics :visits, :pageviews
  dimensions :hour, :dayOfWeek # 0 = Sunday, 6 = Monday
end
class VisitsByPage
  extend Garb::Model

  metrics :visits, :pageviews
  dimensions :page_path
end

class Sources
  extend Garb::Model

  metrics :visits, :pageviews
  dimensions :source, :medium
end
class SourcesWithPath
  extend Garb::Model

  metrics :visits, :pageviews
  dimensions :source, :medium, :referralPath
end
class ReportsController < ApplicationController
  # GET /reports
  # GET /reports.json
  def index
    @reports = Report.all

    @start_date = params[:from] ? params[:from].to_time : Time.now.at_beginning_of_month
    @end_date = params[:to] ? params[:to].to_time.end_of_day : Time.now.yesterday.end_of_day
    @days = (@end_date - @start_date).ceil / 86400
    @first_weekday = @start_date.wday
    @last_weekday = @end_date.wday
    @first_day_count = @days / 7
    @other_day_count = @first_day_count - 1
    @day_leftovers = @days % 7

    @day_counts = [0,0,0,0,0,0,0]

    @day_counts.each_with_index do |day, index|
      if( @first_weekday < @last_weekday )
        partial = (index >= @first_weekday and index <= @last_weekday) ? 1 : 0
      elsif( @first_weekday == @last_weekday )
        partial = (@first_weekday == index) ? 1 : 0
      else
        partial = (index >= @first_weekday or index <= @last_weekday) ? 1 : 0
      end
      count = ((@end_date - @start_date)/60/60/24/7).floor + partial  
      @day_counts[index] =  count
    end


    Garb::Session.login(ENV["GOOGLE_EMAIL"], ENV["GOOGLE_PASSWORD"])

    #profile = Garb::Management::Profile.all.detect {|p| p.web_property_id == 'UA-8011720-1'} #The Jake Group
    profile = Garb::Management::Profile.all.detect {|p| p.web_property_id == 'UA-19314324-1'} #Celadon Spa

    @stats = Visits.results(profile, start_date: @start_date, end_date: @end_date).to_a
    @stats.sort! { |a,b| Integer(b.visits) <=> Integer(a.visits) }

    @mobile = VisitsByMobile.results(profile, start_date: @start_date, end_date: @end_date).to_a
    @mobile.sort! { |a,b| b.is_mobile <=> a.is_mobile }

    @mobile_date_data = VisitsByDateAndMobile.results(profile, start_date: @start_date, end_date: @end_date).to_a
    @mobile_date_data.sort! { |a,b| a.date <=> b.date }

    @visit_data = VisitsByPage.results(profile, start_date: @start_date, end_date: @end_date).to_a
    @visit_data.sort! { |a,b| Integer(b.visits) <=> Integer(a.visits) }

    @visit_date_data = VisitsByDate.results(profile, start_date: @start_date, end_date: @end_date).to_a

    @source_data = Sources.results(profile, start_date: @start_date, end_date: @end_date).to_a
    @source_data.sort! { |a,b| Integer(b.visits) <=> Integer(a.visits) }

    @medium_data = VisitsByMedium.results(profile, start_date: @start_date, end_date: @end_date).to_a
    @medium_data.sort! { |a,b| Integer(b.visits) <=> Integer(a.visits) }
    

    @time_data = StatsByDayAndTime.results(profile, start_date: @start_date, end_date: @end_date).to_a



    @two_d_plot_visits = [[],[],[],[],[],[],[]]
    @two_d_plot_pageviews = [[],[],[],[],[],[],[]]

    @two_d_plot_visits_max = 0
    @two_d_plot_visits_min = 10000000

    @two_d_plot_pageviews_max = 0
    @two_d_plot_pageviews_min = 10000000
  
    @time_data.each do |datum|
      avg_visits = datum.visits.to_i / @day_counts[datum.day_of_week.to_i]
      @two_d_plot_visits[datum.day_of_week.to_i] << avg_visits
      @two_d_plot_visits_max = avg_visits if avg_visits > @two_d_plot_visits_max 
      @two_d_plot_visits_min = avg_visits if avg_visits < @two_d_plot_visits_min

      avg_pvs = datum.pageviews.to_i / @day_counts[datum.day_of_week.to_i]
      @two_d_plot_pageviews[datum.day_of_week.to_i] << avg_pvs
      @two_d_plot_pageviews_max = avg_pvs if avg_pvs > @two_d_plot_pageviews_max 
      @two_d_plot_pageviews_min = avg_pvs if avg_pvs < @two_d_plot_pageviews_min 
    end
    
    # report = Garb::Model.new(profile, {:metrics => [:visits]})
    #  = report.all
    #  
    @total_visits = @stats.first.visits
    @total_pageviews = @stats.first.pageviews

    @total_mobile_visits = @mobile.first.visits
    @total_mobile_pageviews = @mobile.first.pageviews

    @percentage_mobile_visits = 100 * @total_mobile_visits.to_f / @total_visits.to_f
    @percentage_mobile_pageviews = 100 * @total_mobile_pageviews.to_f / @total_pageviews.to_f

    @media = {
      organic: { visits: 0, pageviews: 0},
      referral: { visits: 0, pageviews: 0},
      direct: { visits: 0, pageviews: 0}
    }

    @medium_data.each do |result|
      case result.medium
      when 'organic'
        @media[:organic][:visits] = result.visits
        @media[:organic][:pageviews] = result.pageviews
      when 'referral'
        @media[:referral][:visits] = result.visits
        @media[:referral][:pageviews] = result.pageviews
      when '(none)'
        @media[:direct][:visits] = result.visits
        @media[:direct][:pageviews] = result.pageviews
      end
    end

    @percentage_organic_visits = 100 * @media[:organic][:visits].to_f / @total_visits.to_f
    @percentage_referral_visits = 100 * @media[:referral][:visits].to_f / @total_visits.to_f
    @percentage_direct_visits = 100 * @media[:direct][:visits].to_f / @total_visits.to_f

    @months = {}

    @visit_date_data
    visits_days = []
    pageviews_days = []
    weekend_visits_days = []
    weekend_pageviews_days = []
    weekday_visits_days = []
    weekday_pageviews_days = []

    @visit_date_data.each do |day|
      visits_days << day.visits.to_f
      pageviews_days << day.pageviews.to_f

      if day.day_of_week.to_i != 6 && day.day_of_week.to_i != 0
        weekday_visits_days << day.visits.to_f
        weekday_pageviews_days << day.pageviews.to_f
      else
        weekend_visits_days << day.visits.to_f
        weekend_pageviews_days << day.pageviews.to_f
      end
    end

    xs = (0...visits_days.length).to_a
    weekend_xs = (0...weekend_visits_days.length).to_a
    weekday_xs = (0...weekday_visits_days.length).to_a
    visits_ys = visits_days
    pageviews_ys = pageviews_days

    @visits_linear_model = SimpleLinearRegression.new(xs, visits_ys)
    @pageviews_linear_model = SimpleLinearRegression.new(xs, pageviews_ys)

    @weekday_visits_linear_model = SimpleLinearRegression.new(weekday_xs, weekday_visits_days)
    @weekday_pageviews_linear_model = SimpleLinearRegression.new(weekday_xs, weekday_pageviews_days)

    @weekend_visits_linear_model = SimpleLinearRegression.new(weekend_xs, weekend_visits_days)
    @weekend_pageviews_linear_model = SimpleLinearRegression.new(weekend_xs, weekend_pageviews_days)

    @full_date_data = []
    @date_data_mobile = {}

    @mobile_date_data.each do |day|
      if day.is_mobile == "Yes"
        @date_data_mobile[day.date] = day.visits
      end
    end

    @visit_date_data.each do |day|
      @full_date_data << [day.date, day.visits]
    end

    @mobile_percentage_by_date = {}
    @full_date_data.each do |day|
      date = day[0]
      total_visits = day[1]
      mobile_visits = @date_data_mobile[date]
      @mobile_percentage_by_date[date] = 100 * mobile_visits.to_i / total_visits.to_i
    end
    @mobile_visit_data = []
    @mobile_percentage_by_date.each{ |date| @mobile_visit_data << date[1] }

    @mobile_visits_linear_model = SimpleLinearRegression.new(xs, @mobile_visit_data)

    visits_by_day = [[],[],[],[],[],[],[]]
    pageviews_by_day = [[],[],[],[],[],[],[]]

    @visit_date_data.each do |day|
      visits_by_day[day.day_of_week.to_i] << day.visits.to_i
      pageviews_by_day[day.day_of_week.to_i] << day.pageviews.to_i
    end

    @day_visit_averages = []
    @day_pageview_averages = []

    visits_by_day.each_with_index do |day, index|
      day_count = 0
      day_sum = 0

      day.each do |d|
        day_sum = day_sum + d
        day_count = day_count + 1
      end
      @day_visit_averages[index] = day_count > 0 ? day_sum/day_count : 0
    end

    pageviews_by_day.each_with_index do |day, index|
      day_count = 0
      day_sum = 0

      day.each do |d|
        day_sum = day_sum + d
        day_count = day_count + 1
      end
      @day_pageview_averages[index] = day_count > 0 ? day_sum/day_count : 0
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @reports }
    end
  end

  # GET /reports/1
  # GET /reports/1.json
  def show
    @report = Report.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @report }
    end
  end

  # GET /reports/new
  # GET /reports/new.json
  def new
    @report = Report.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @report }
    end
  end

  # GET /reports/1/edit
  def edit
    @report = Report.find(params[:id])
  end

  # POST /reports
  # POST /reports.json
  def create
    @report = Report.new(params[:report])

    respond_to do |format|
      if @report.save
        format.html { redirect_to @report, notice: 'Report was successfully created.' }
        format.json { render json: @report, status: :created, location: @report }
      else
        format.html { render action: "new" }
        format.json { render json: @report.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /reports/1
  # PUT /reports/1.json
  def update
    @report = Report.find(params[:id])

    respond_to do |format|
      if @report.update_attributes(params[:report])
        format.html { redirect_to @report, notice: 'Report was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @report.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /reports/1
  # DELETE /reports/1.json
  def destroy
    @report = Report.find(params[:id])
    @report.destroy

    respond_to do |format|
      format.html { redirect_to reports_url }
      format.json { head :no_content }
    end
  end
end
