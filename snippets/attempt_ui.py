
from kivy.app import App
from kivy.lang import Builder
from kivy.factory import Factory
from kivymd.cards import MDCardPost
from kivymd.theming import ThemeManager
from kivymd.toast import toast

TEXT = """Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer interdum a dolor at pharetra. Morbi fermentum accumsan massa. Mauris varius erat eu odio auctor, ut tincidunt diam pretium. Cras laoreet erat sit amet libero congue, vel tristique neque finibus. Phasellus vitae dictum lacus. Pellentesque tristique lectus at pretium ultricies. Maecenas tincidunt sem tortor, sed efficitur est elementum vel. Proin auctor ac orci sit amet malesuada. Duis nec sollicitudin neque. Sed at molestie nulla. Morbi sit amet ornare urna, nec commodo ipsum. Donec efficitur metus egestas arcu tempor placerat. In et pulvinar purus. Fusce ipsum quam, mollis eget justo id, consectetur ornare justo. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Praesent et dolor luctus enim fermentum facilisis id sed urna.

Donec et bibendum dui. Maecenas ex risus, semper in aliquam convallis, varius id velit. Mauris rutrum ex vitae libero scelerisque, vitae lobortis erat porttitor. Nunc sed ex id augue ornare imperdiet. Duis ac ex quis tellus luctus sagittis eu vulputate eros. Integer nec consequat enim, quis condimentum urna. Nullam risus urna, maximus sed finibus sed, dictum quis mauris. Suspendisse fermentum ut lacus nec laoreet. Curabitur blandit varius porta. Fusce aliquet dolor leo, at viverra neque rhoncus sit amet."""


Builder.load_string('''
#:import MDToolbar kivymd.toolbar.MDToolbar
<ExampleCardPost@BoxLayout>
    orientation: 'vertical'
    spacing: dp(5)
    MDToolbar:
        id: toolbar
        title: app.title
        left_action_items: [['menu', lambda x: None]]
        elevation: 10
        md_bg_color: app.theme_cls.primary_color
    ScrollView:
        id: scroll
        size_hint: 1, 1
        do_scroll_x: False
        GridLayout:
            id: grid_card
            cols: 1
            spacing: dp(5)
            padding: dp(5)
            size_hint_y: None
            height: self.minimum_height
''')
class Example(App):
    theme_cls = ThemeManager()
    theme_cls.primary_palette = 'Teal'
    title = "Card Post"
    cards_created = False
    def build(self):
        self.screen = Factory.ExampleCardPost()
        return self.screen
    def on_start(self):
        def callback_for_menu_items(text_item):
            toast(text_item)
        def callback(instance, value):
            if value and isinstance(value, int):
                toast('Set like in %d stars' % value)
            elif value and isinstance(value, str):
                toast('Repost with %s ' % value)
            elif value and isinstance(value, list):
                toast(value[1])
            else:
                toast('Delete post %s' % str(instance))
        instance_grid_card = self.screen.ids.grid_card
        buttons = ['facebook', 'vk', 'twitter']
        menu_items = [
            {'viewclass': 'MDMenuItem',
             'text': 'Example item %d' % i,
             'callback': callback_for_menu_items}
            for i in range(2)
        ]
        if not self.cards_created:
            self.cards_created = True
            instance_grid_card.add_widget(
                MDCardPost(text_post='Card with text',
                           swipe=True, callback=callback))
            instance_grid_card.add_widget(
                MDCardPost(
                    right_menu=menu_items, swipe=True,
                    text_post=TEXT,
                    callback=callback))
            instance_grid_card.add_widget(
                MDCardPost(
                    likes_stars=True, callback=callback, swipe=True,
                    text_post='Card with asterisks for voting.'))
            instance_grid_card.add_widget(
                MDCardPost(
                    source="./assets/kitten-1049129_1280.jpg",
                    tile_text="Little Baby",
                    tile_font_style="H5",
                    text_post="This is my favorite cat. He's only six months "
                              "old. He loves milk and steals sausages :) "
                              "And he likes to play in the garden.",
                    with_image=True, swipe=True, callback=callback,
                    buttons=buttons))
Example().run()
