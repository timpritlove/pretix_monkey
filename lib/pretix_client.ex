defmodule PretixClient do
  @moduledoc """
  A client for the Pretix REST API that fetches all invoices and exports them to CSV.
  """

  @api_url "https://pretix.eu/api/v1"
  @token "51msab7jc1sthqlalwdfz10x02ri4aui2nvo80gvpqa8dqawwr429jmwh2tq2xxl"
  @organizer "metaebene"
  @event "subscribe11"

  @konto_haben_19 "4400"
  @konto_haben_7 "4300"
  @konto_soll "8603"
  @kostenstelle "SUBSCRIBE11x"
  @belegnr "Pretix"

  def get_all_invoices do
    invoices_url = "#{@api_url}/organizers/#{@organizer}/events/#{@event}/invoices/"
    fetch_all_invoices(invoices_url)
  end

  defp fetch_all_invoices(url, accumulated_invoices \\ []) do
    headers = [{"Authorization", "Token #{@token}"}]

    case Req.get(url, headers: headers) do
      {:ok, response} when response.status == 200 ->
        body = response.body
        results = body["results"]
        next_page = body["next"]

        new_accumulated_invoices = accumulated_invoices ++ results

        if next_page do
          fetch_all_invoices(next_page, new_accumulated_invoices)
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

  defp format_amount(amount) when is_binary(amount) do
    {float_amount, _} = Float.parse(amount)
    format_amount(float_amount)
  end

  defp format_amount(amount) when is_float(amount) do
    amount
    |> Float.to_string()
    |> String.replace(".", ",")
  end

  defp get_konto_haben(tax_rate) do
    case tax_rate do
      "19.00" -> @konto_haben_19
      "7.00" -> @konto_haben_7
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

  defp convert_invoice_to_csv_lines(invoice) do
    invoice["lines"]
    |> Enum.map(fn line ->
      date = invoice["date"] |> Date.from_iso8601!() |> Calendar.strftime("%d.%m.%Y")
      [
        date,
        @belegnr,  # BelegNr
        "",  # Referenz
        format_amount(line["gross_value"]),
        "EUR",
        line["description"],
        @konto_soll,
        get_konto_haben(line["tax_rate"]),
        get_steuersatz(line["tax_rate"]),  # Updated Steuersatz field
        @kostenstelle,
        "",  # Kostenstelle2
        ""   # Notiz
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
    {opts, _, _} = OptionParser.parse(args,
      switches: [output: :string],
      aliases: [o: :output]
    )

    get_all_invoices()
    |> Enum.flat_map(&convert_invoice_to_csv_lines/1)
    |> write_csv(opts[:output])
  end
end
