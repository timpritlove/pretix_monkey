defmodule PretixMonkey do
  @moduledoc """
  A client for the Pretix REST API that fetches all invoices and exports them to CSV.

  Usage:
    pretix_monkey [options]

  Options:
    -o, --output            Output file path (defaults to stdout)
    -O, --organizer         Pretix organizer slug (or PRETIX_ORGANIZER env var)
    -E, --event            Pretix event slug (or PRETIX_EVENT env var)
    -T, --token            Pretix API token (or PRETIX_TOKEN env var)
    -1, --ks1              Kostenstelle1 (optional)
    -2, --ks2              Kostenstelle2 (optional)
    -B, --belegnr          BelegNr prefix (defaults to "Pretix")
    -V, --verrechnungskonto Account number (defaults to "9000")
    -K, --kontenrahmen     Chart of accounts, "skr03" or "skr04" (defaults to "skr04")

  Environment:
    PRETIX_ORGANIZER      Alternative to --organizer
    PRETIX_EVENT         Alternative to --event
    PRETIX_TOKEN         Alternative to --token
  """

  @api_url "https://pretix.eu/api/v1"

  @default_kostenstelle1 ""
  @default_kostenstelle2 ""
  @default_belegnr "Pretix"

  @konto_haben %{
    "skr03" => %{"19" => "8400", "7" => "8300"},
    "skr04" => %{"19" => "4400", "7" => "4300"}
  }
  @default_kontenrahmen "skr04"
  @default_verrechnungskonto "9000"

  def get_all_invoices(api_base_url, token) do
    invoices_url = "#{api_base_url}/invoices/"
    fetch_all_invoices(invoices_url, token)
  end

  defp fetch_all_invoices(url, token, accumulated_invoices \\ []) do
    headers = [{"Authorization", "Token #{token}"}]

    case Req.get(url, headers: headers) do
      {:ok, response} when response.status == 200 ->
        body = response.body
        results = body["results"]
        next_page = body["next"]

        new_accumulated_invoices = accumulated_invoices ++ results

        if next_page do
          fetch_all_invoices(next_page, token, new_accumulated_invoices)
        else
          new_accumulated_invoices
        end

      {:ok, response} ->
        IO.puts("Failed to fetch invoices: HTTP #{response.status}")
        accumulated_invoices

      {:error, reason} ->
        IO.puts("HTTP error: #{reason}")
        accumulated_invoices
    end
  end

  def get_all_items(api_base_url, token) do
    items_url = "#{api_base_url}/items/"
    fetch_all_items(items_url, token)
  end

  defp fetch_all_items(url, token, accumulated_items \\ []) do
    headers = [{"Authorization", "Token #{token}"}]

    case Req.get(url, headers: headers) do
      {:ok, response} when response.status == 200 ->
        body = response.body
        results = body["results"]
        next_page = body["next"]

        new_accumulated_items = accumulated_items ++ results

        if next_page do
          fetch_all_items(next_page, token, new_accumulated_items)
        else
          new_accumulated_items
        end

      {:ok, response} ->
        IO.puts("Failed to fetch items: HTTP #{response.status}")
        accumulated_items

      {:error, reason} ->
        IO.puts("HTTP error: #{reason}")
        accumulated_items
    end
  end

  defp format_amount(amount) when is_binary(amount) do
    {float_amount, _} = Float.parse(amount)
    format_amount(float_amount)
  end

  defp format_amount(amount) when is_float(amount) do
    amount
    |> Float.to_string()
    |> String.replace(".", ",")
  end

  defp get_konto_haben(tax_rate, kontenrahmen) do
    case tax_rate do
      "19.00" -> @konto_haben[String.downcase(kontenrahmen)]["19"]
      "7.00" -> @konto_haben[String.downcase(kontenrahmen)]["7"]
      _ -> ""
    end
  end

  defp get_steuersatz(tax_rate) do
    case tax_rate do
      "19.00" -> "USt19"
      "7.00" -> "USt7"
      _ -> ""
    end
  end

  defp convert_invoice_to_csv_lines(
         invoice,
         items_map,
         kostenstelle1,
         kostenstelle2,
         belegnr,
         verrechnungskonto,
         kontenrahmen
       ) do
    # Get the invoice number from the invoice data
    invoice_number = "#{belegnr}-#{invoice["number"]}"

    invoice["lines"]
    |> Enum.map(fn line ->
      date = invoice["date"] |> Date.from_iso8601!() |> Calendar.strftime("%d.%m.%Y")

      description =
        case line["item"] do
          nil ->
            line["description"]

          item_id ->
            item = Map.get(items_map, item_id)

            if item,
              do: item["name"]["de-informal"] || line["description"],
              else: line["description"]
        end

      [
        date,
        invoice_number,
        "",
        format_amount(line["gross_value"]),
        "EUR",
        description,
        verrechnungskonto,
        get_konto_haben(line["tax_rate"], kontenrahmen),
        get_steuersatz(line["tax_rate"]),
        kostenstelle1,
        kostenstelle2,
        line["description"]
      ]
    end)
  end

  defp write_csv(data, output_file) do
    header = [
      "Datum",
      "BelegNr",
      "Referenz",
      "Betrag",
      "Währung",
      "Text",
      "KontoSoll",
      "KontoHaben",
      "Steuersatz",
      "Kostenstelle1",
      "Kostenstelle2",
      "Notiz"
    ]

    csv_data = [header | data]
    csv_string = NimbleCSV.RFC4180.dump_to_iodata(csv_data) |> IO.iodata_to_binary()

    case output_file do
      nil ->
        # Write to stdout
        IO.write(csv_string)

      filename ->
        # Write to file
        File.write!(filename, csv_string)
        IO.puts("CSV export completed: #{filename}")
    end
  end

  def main(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          output: :string,
          organizer: :string,
          event: :string,
          token: :string,
          ks1: :string,
          ks2: :string,
          belegnr: :string,
          verrechnungskonto: :string,
          kontenrahmen: :string
        ],
        aliases: [
          o: :output,
          O: :organizer,
          E: :event,
          T: :token,
          "1": :ks1,
          "2": :ks2,
          B: :belegnr,
          V: :verrechnungskonto,
          K: :kontenrahmen
        ]
      )

    # Get values from opts with environment variables and defaults as fallbacks
    organizer = opts[:organizer] || System.get_env("PRETIX_ORGANIZER")
    event = opts[:event] || System.get_env("PRETIX_EVENT")
    token = opts[:token] || System.get_env("PRETIX_TOKEN")
    kostenstelle1 = opts[:ks1] || @default_kostenstelle1
    kostenstelle2 = opts[:ks2] || @default_kostenstelle2
    belegnr = opts[:belegnr] || @default_belegnr
    verrechnungskonto = opts[:verrechnungskonto] || @default_verrechnungskonto

    # Create base URL with parameters
    api_base_url = "#{@api_url}/organizers/#{organizer}/events/#{event}"

    # Fetch items first and create a map for easy lookup
    items_map =
      get_all_items(api_base_url, token)
      |> Enum.map(fn item -> {item["id"], item} end)
      |> Map.new()

    kontenrahmen = opts[:kontenrahmen] || @default_kontenrahmen

    # Validate kontenrahmen
    if String.downcase(kontenrahmen) not in ["skr03", "skr04"] do
      IO.puts("Error: Kontenrahmen must be either 'skr03' or 'skr04'")
      System.halt(1)
    end

    get_all_invoices(api_base_url, token)
    |> Enum.flat_map(
      &convert_invoice_to_csv_lines(
        &1,
        items_map,
        kostenstelle1,
        kostenstelle2,
        belegnr,
        verrechnungskonto,
        kontenrahmen
      )
    )
    |> write_csv(opts[:output])
  end
end
