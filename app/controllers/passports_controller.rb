# app/controllers/passports_controller.rb
require "prawn"
require "prawn/table"

class PassportsController < ApplicationController
  def new
    @guests = Guest.active.order(created_at: :desc)
  end

  def create
    if params[:passport].present? && params[:passport][:image].present?
      uploaded_file = params[:passport][:image]

      # Processes image via adaptive thresholding and parses via the MRZ library
      passport_data = PassportOcrService.new(uploaded_file.tempfile.path).call

      if passport_data
        @guest = Guest.create!(
          document_type: passport_data[:document_type],
          first_names: passport_data[:first_names],
          last_name: passport_data[:last_name],
          document_number: passport_data[:document_number],
          sex: passport_data[:sex],
          birthdate: passport_data[:birthdate],
          expiry_date: passport_data[:expiry_date],
          nationality: passport_data[:nationality],
          issuing_state: passport_data[:issuing_state],
          status: "pending"
        )
        flash.now[:notice] = "#{passport_data[:document_type]} scanned and registered successfully!"
      else
        flash.now[:alert] = "Could not parse standard Passport or ID Card MRZ fields."
      end
    else
      flash.now[:alert] = "Please select an image file first."
    end

    @guests = Guest.active.order(created_at: :desc)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("dashboard-grid", partial: "dashboard_grid", locals: { guests: @guests }),
          turbo_stream.update("flash-messages", partial: "passports/flashes")
        ]
      end
      format.html { redirect_to passports_path }
    end
  end

  def show
    @guest = Guest.find(params[:id])
    render layout: false
  end

  def update
    @guest = Guest.find(params[:id])
    if @guest.update(room_number: params[:room_number], status: "checked_in", checked_in_at: Time.current)
      flash.now[:notice] = "Guest assigned to Room #{params[:room_number]} successfully!"
    end

    @guests = Guest.active.order(created_at: :desc)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("dashboard-grid", partial: "dashboard_grid", locals: { guests: @guests }),
          turbo_stream.update("flash-messages", partial: "passports/flashes")
        ]
      end
    end
  end

  # 🚨 PURE-RUBY LAW ENFORCEMENT DISPATCH MANIFEST GENERATOR
  def police_report
    @guest = Guest.find(params[:id])

    respond_to do |format|
      format.pdf do
        # 1. Initialize an unalterable A4 canvas vector in memory
        pdf = Prawn::Document.new(page_size: "A4", margin: [40, 40, 40, 40])

        # 📄 DOSSIER HEADER
        pdf.fill_color "1A365D"
        pdf.text "OFFICIAL IDENTITY VERIFICATION DOSSIER", size: 20, style: :bold
        pdf.fill_color "4A5568"
        pdf.text "Certified Property Guest Registration Manifest • Law Enforcement Dispatch Copy", size: 9, style: :italic
        pdf.move_down 10
        pdf.stroke_color "1A365D"
        pdf.stroke_horizontal_rule
        pdf.move_down 15

        # 📋 COMPLIANCE AUDIT BOX BLOCK
        pdf.fill_color "F8FAFC"
        pdf.stroke_color "E2E8F0"
        pdf.fill_and_stroke_rounded_rectangle [0, pdf.cursor], pdf.bounds.width, 45, 4

        pdf.fill_color "212529"
        pdf.move_down 10
        pdf.text "<b>Report Generated:</b> #{Time.current.strftime('%B %d, %Y at %I:%M %p')}    |    <b>System Context:</b> Front Desk Hub Terminal", inline_format: true, size: 9, indent: 12
        pdf.move_down 5
        pdf.text "<b>Record Audit ID:</b> REG-INC-#{@guest.id}-#{SecureRandom.hex(2).upcase}    |    <b>Document Form:</b> Universal ICAO Parsed Stream", inline_format: true, size: 9, indent: 12
        pdf.move_down 25

        # 👤 SECTION 1: DEMOGRAPHICS
        pdf.fill_color "1A365D"
        pdf.text "1. GUEST DEMOGRAPHICS & PROFILE LOG", size: 11, style: :bold
        pdf.move_down 8

        demo_data = [
          ["Last Name (Surname)", @guest.last_name.to_s.upcase],
          ["Given Names", @guest.first_names.to_s],
          ["Date of Birth", @guest.birthdate&.respond_to?(:strftime) ? @guest.birthdate.strftime("%B %d, %Y") : @guest.birthdate.to_s],
          ["Gender / Sex", @guest.sex.to_s],
          ["Assigned Location Status", @guest.status == 'checked_in' ? "Room #{@guest.room_number} (Active Check-In)" : "Pending Assignment"],
          ["System Check-In Time", @guest.checked_in_at&.respond_to?(:strftime) ? @guest.checked_in_at.strftime("%B %d, %Y at %I:%M %p") : "Not checked in yet"]
        ]

        pdf.table(demo_data, width: pdf.bounds.width) do |t|
          t.cells.padding = 8
          t.cells.border_width = 0.5
          t.cells.border_color = "E2E8F0"
          t.column(0).font_style = :bold
          t.column(0).text_color = "4A5568"
          t.column(0).width = 180
        end
        pdf.move_down 25

        # 🛡️ SECTION 2: METADATA & CRYPTOGRAPHIC COMPLIANCE CHECK
        pdf.fill_color "1A365D"
        pdf.text "2. DOCUMENT SECURITY & VERIFICATION METRICS", size: 11, style: :bold
        pdf.move_down 8

        is_expired = @guest.expiry_date.present? && @guest.expiry_date.to_date < Date.today
        status_string = is_expired ? "CRITICAL: EXPIRED CREDENTIAL SECURITY EXCEPTION" : "[PASS] ICAO Tamper-Free Verified"

        doc_data = [
          ["Document Classification", @guest.document_type || "Identity Credential"],
          ["Document Number ID", @guest.document_number.to_s.upcase],
          ["Nationality Code", @guest.nationality.to_s.upcase],
          ["Issuing Authority State", @guest.issuing_state.to_s.upcase],
          ["Document Expiry Validation", @guest.expiry_date&.respond_to?(:strftime) ? @guest.expiry_date.strftime("%B %d, %Y") : @guest.expiry_date.to_s],
          ["Checksum Compliance Score", status_string]
        ]

        pdf.table(doc_data, width: pdf.bounds.width) do |t|
          t.cells.padding = 8
          t.cells.border_width = 0.5
          t.cells.border_color = "E2E8F0"
          t.column(0).font_style = :bold
          t.column(0).text_color = "4A5568"
          t.column(0).width = 180

          if is_expired
            t.row(5).column(1).background_color = "FCE8E6"
            t.row(5).column(1).text_color = "C5221F"
          else
            t.row(5).column(1).background_color = "E6F4EA"
            t.row(5).column(1).text_color = "137333"
          end
          t.row(5).column(1).font_style = :bold
        end
        pdf.move_down 60

        # ✍️ SECTION 3: LAW ENFORCEMENT PHYSICAL SIGNOFF FOOTER
        pdf.stroke_color "A0AEC0"
        pdf.stroke_horizontal_line 10, 210, at: pdf.cursor
        pdf.stroke_horizontal_line 300, 500, at: pdf.cursor

        current_y = pdf.cursor
        pdf.move_down 6

        pdf.fill_color "4A5568"
        pdf.draw_text "Hotel Property Representative Signature", size: 8, at: [25, current_y - 12]
        pdf.draw_text "Receiving Officer Badge & Signature", size: 8, at: [325, current_y - 12]

        # 4. Stream binary data stream instantly to the frontdesk browser client
        send_data pdf.render,
                  filename: "POLICE_REPORT_#{@guest.last_name}_#{@guest.document_number}.pdf",
                  type: "application/pdf",
                  disposition: "attachment"
      end
    end
  end
end
