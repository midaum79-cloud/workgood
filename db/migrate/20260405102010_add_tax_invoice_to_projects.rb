class AddTaxInvoiceToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :tax_invoice_issued, :boolean, default: false
  end
end
