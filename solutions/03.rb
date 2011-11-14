require 'bigdecimal'
require 'bigdecimal/util'

class Product
  attr_reader :name, :price
  
  def initialize(name, price)
    @name, @price = name, price
  end
  
  def counted_price( count )
    count * price
  end
end

class NoPromotion
  attr_reader :product

  def initialize(name, price, *future)
    @product = Product.new name, price
  end
  
  def promoted_price(count)
    product.counted_price(count) - discount(count)
  end
  
  def discount(count)
    '0'.to_d
  end
  
  def message()
    ''
  end
end

class OneFreePromotion < NoPromotion
  def initialize(name, price, nth_item)
    super
    @nth_item = nth_item
  end

  def discount(count)
    product.price * ( count / @nth_item )
  end

  def message
    "(buy #{@nth_item-1}, get 1 free)"
  end
end

class PackagePromotion < NoPromotion

  attr_reader :package_size, :package_discount
  
  def initialize(name, price, package_info)
    super
    @package_size = package_info.keys[0]
    @package_discount = package_info[@package_size]
  end
  
  def discount(count)
    promoted_products_count = (count / package_size) * package_size
    product.price * promoted_products_count * (package_discount / '100'.to_d)
  end

  def message  
    "(get #{package_discount}% off for every #{package_size})"
  end
end

class TreshholdPromotion < NoPromotion
  attr_reader :treshhold, :treshhold_percent

  def initialize(name, price, treshhold_info)
    super
    @treshhold = treshhold_info.keys.fetch 0
    @treshhold_percent = treshhold_info[treshhold]
  end
  
  def discount(count)
    return '0'.to_d if treshhold >= count
    product.price * ( count - treshhold ) * ( treshhold_percent / '100'.to_d )
  end
  
  def message
    "(#{treshhold_percent}% off of every after the #{place})"
  end
  
  private
  
  def place
    case treshhold
      when 1 then '1st'
      when 2 then '2nd'
      when 3 then '3rd'
      else "#{treshhold}th"
    end
  end
end

class PercentCoupon
  attr_reader :name, :percent
  
  def initialize(name, percent)
    @name, @percent = name, percent
  end
  
  def discount(money_from)
    money_from * ( percent / '100'.to_d )
  end
  
  def message
    "Coupon #{name} - #{percent}% off"
  end
end

class AmountCoupon
  attr_reader :name, :amount
  
  def initialize(name, amount)
    @name, @amount = name, amount.to_d
  end
  
  def discount(money_from)
    return money_from if amount >= money_from
    amount
  end
  
  def message
    "Coupon #{name} - #{sprintf "%.2f", amount.round(2).to_f} off"
  end
end

class Inventory
  attr_reader :products, :coupons

  def Inventory.item_factory(name, price, promotion)
    key = promotion.keys[0]
    case key
      when :get_one_free then OneFreePromotion.new name, price, promotion[key]
      when :package then PackagePromotion.new name, price, promotion[key]
      when :threshold then TreshholdPromotion.new name, price, promotion[key]
      else NoPromotion.new(name, price)
    end
  end
  
  def Inventory.coupon_factory(name, params)
    key = params.keys[0]
    case key 
      when :percent then PercentCoupon.new name, params[key]
      when :amount then AmountCoupon.new name, params[key]
      else raise "Unknown coupon type!"
    end
  end

  def initialize()
    @products, @coupons = {}, {}
  end
  
  def has_product?(name)
    products.has_key? name
  end
  
  def register(name, price='0', promotion = {})
    raise "'#{name}' is in inventory!." if has_product? name
    raise "Invalid name passed" if name.length > 40
    raise "Invalid price passed - too low" unless price.to_d.round(2) > 0
    raise "Invalid price passed - too high" unless price.to_d.round(2) < 1000
    products[name] = Inventory.item_factory name, price.to_d, promotion
  end
  
  def register_coupon(name, params)
    raise "#{name} coupon is in inventory!" if coupons.has_key? name
    coupons[name] = Inventory.coupon_factory name, params
  end
  
  def new_cart()
    Cart.new self
  end
end

class CartItem
  attr_reader :inventory_item, :count

  def initialize(inventory_item_paramter)
    @inventory_item, @count = inventory_item_paramter, 0
  end
  
  def add(more)
    new_count = count + more
    raise "Too many products!" if new_count > 99
    raise "Invalid product count!" if new_count <= 0
    @count = new_count
  end
  
  def name
    inventory_item.product.name
  end
  
  def price
    inventory_item.product.counted_price count
  end
  
  def promoted_price
    inventory_item.promoted_price count
  end
  
  def discount
    -(inventory_item.discount count)
  end
  
  def message
    inventory_item.message
  end
end

class Cart
  attr_reader :inventory, :items, :coupon, :coupon_discount
  
  def initialize(used_inventory)
    @inventory, @items = used_inventory, {}
  end
  
  def add(name, count = 1)
    raise "Undefined product!" unless inventory.has_product? name
    item = items[name] || items[name] = CartItem.new(inventory.products[name])
    item.add count
  end
  
  def use coupon_name
    raise "A coupon is already used!" if coupon
    @coupon = inventory.coupons[coupon_name]
  end
  
  def products_total
    items.values.map(&:promoted_price).inject(:+)
  end
  
  def total
    result = products_total 
    result -= coupon.discount(result) if coupon
    result
  end
  
  def invoice
    Invoice.new(self).to_s
  end
  
end

class InvoiceRow
  attr_reader :cart_item
  
  def initialize(cart_item_param)
    @cart_item = cart_item_param
  end
  
  def InvoiceRow.generate(name, count, price, message='', discount='')
    name, count  = name.ljust(40), count.to_s.rjust(4)
    price = price.to_s.rjust(8)
    product, promotion = "| #{name}  #{count} | #{price} |\n", ''
    if message != ''
      message, discount = message.to_s.ljust(44), discount.to_s.rjust(8)
      promotion = "|   #{message} | #{discount} |\n" 
    end
    product + promotion	
  end
  
  def to_s
    ci = cart_item
    price = sprintf("%.2f", ci.price.round(2).to_f)
    discount = sprintf("%.2f", ci.discount.round(2).to_f)
    InvoiceRow.generate(ci.name, ci.count, price, ci.message, discount)
  end
end

class Invoice
  attr_reader :cart
  def initialize(shopping_cart)
    @cart = shopping_cart
  end
  
  def to_s()
    delimit + header + delimit + products + coupon + delimit + total + delimit
  end
  
  private
  
  def delimit
    "+------------------------------------------------+----------+\n"
  end
  
  def header()
    InvoiceRow.generate('Name', 'qty', 'price')
  end
  
  def total()
    InvoiceRow.generate('TOTAL', '', sprintf("%.2f", cart.total.round(2).to_f))
  end
  
  def products
    cart.items.values.map { |item| InvoiceRow.new(item).to_s }.join ''
  end
  
  def coupon
    return '' unless cart.coupon
    discount = -(cart.coupon.discount(cart.products_total).round(2).to_f)
    InvoiceRow.generate(cart.coupon.message, '', sprintf("%.2f", discount))
  end
end